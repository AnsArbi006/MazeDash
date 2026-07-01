export interface Env {
    DB: D1Database
}

type LeaderboardEntry = {
    name: string
    score: number
}

type SubmissionPayload = {
    name?: unknown
    previousName?: unknown
    duration?: unknown
    level?: unknown
    score?: unknown
}

type RateLimitRecord = {
    request_count: number
}

const ALLOWED_DURATIONS = new Set([60, 120, 180])
const STORY_LEVEL_MIN = 1
const STORY_LEVEL_MAX = 999
const STORY_SCOPE_OFFSET = 10_000
const MAX_NAME_LENGTH = 16
const TOP_LIMIT = 10
const MAX_SCORE_BY_DURATION: Record<number, number> = {
    60: 100,
    120: 200,
    180: 300
}
const MAX_STORY_TIME_SCORE = 3_600_000
const RATE_LIMITS = {
    get: { windowSeconds: 30, maxRequests: 60 },
    post: { windowSeconds: 600, maxRequests: 20 }
} as const
const BLOCKED_NAME_PARTS = [
    "fuck", "shit", "bitch", "cunt", "nigger", "nigga", "fag", "faggot", "whore", "slut",
    "rape", "rapist", "hitler", "nazi", "terror", "kkk", "porn", "sex", "anal", "penis",
    "vagina", "dick", "cock", "pussy", "asshole", "motherfucker"
]

export default {
    async fetch(request: Request, env: Env): Promise<Response> {
        const url = new URL(request.url)

        if (request.method === "OPTIONS") {
            return withCors(new Response(null, { status: 204 }))
        }

        if (url.pathname !== "/leaderboard") {
            return json({ error: "Not found" }, 404)
        }

        try {
            if (request.method === "GET") {
                await enforceRateLimit(request, env, "get")
                return await handleGet(url, env)
            }
            if (request.method === "POST") {
                await enforceRateLimit(request, env, "post")
                return await handlePost(request, env)
            }
            return json({ error: "Method not allowed" }, 405)
        } catch (error) {
            if (error instanceof Response) {
                return error
            }
            console.error("Leaderboard worker error", error)
            return json({ error: "Internal server error" }, 500)
        }
    }
}

async function handleGet(url: URL, env: Env): Promise<Response> {
    const scope = resolveScopeFromQuery(url)
    if (!scope) {
        return json({ error: "Invalid leaderboard scope" }, 400)
    }

    const orderClause = scope.ascending ? "score ASC, achieved_at ASC, id ASC" : "score DESC, achieved_at ASC, id ASC"

    const { results } = await env.DB.prepare(
        `
        SELECT player_name AS name, score
        FROM leaderboard_entries
        WHERE duration = ?
        ORDER BY ${orderClause}
        LIMIT ?
        `
    )
        .bind(scope.scopeValue, TOP_LIMIT)
        .all<LeaderboardEntry>()

    return json(results ?? [], 200, {
        "cache-control": "public, max-age=15"
    })
}

async function handlePost(request: Request, env: Env): Promise<Response> {
    const payload = (await request.json()) as SubmissionPayload
    const name = sanitizeName(payload.name)
    const previousName = payload.previousName == null ? null : sanitizeName(payload.previousName)
    const score = Number(payload.score)
    const scope = resolveScopeFromPayload(payload)

    if (!name) {
        return json({ error: "Invalid player name" }, 400)
    }
    if (!scope) {
        return json({ error: "Invalid leaderboard scope" }, 400)
    }
    if (!Number.isInteger(score) || score < 0 || score > scope.maxScore) {
        return json({ error: "Invalid score" }, 400)
    }

    const existing = await env.DB.prepare(
        `
        SELECT score
        FROM leaderboard_entries
        WHERE player_name = ? AND duration = ?
        LIMIT 1
        `
    )
        .bind(name, scope.scopeValue)
        .first<{ score: number }>()

    const previousEntry =
        previousName && previousName !== name
            ? await env.DB.prepare(
                `
                SELECT score
                FROM leaderboard_entries
                WHERE player_name = ? AND duration = ?
                LIMIT 1
                `
            )
                .bind(previousName, scope.scopeValue)
                .first<{ score: number }>()
            : null

    const mergedScore = mergeScores(
        scope.ascending,
        existing?.score ?? null,
        previousEntry?.score ?? null,
        score
    )

    const bestUnchanged =
        existing &&
        mergedScore === existing.score &&
        (!previousEntry || previousName === name)
    if (bestUnchanged) {
        return json({ accepted: false, bestUnchanged: true })
    }

    if (existing) {
        await env.DB.prepare(
            `
            UPDATE leaderboard_entries
            SET score = ?, achieved_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
            WHERE player_name = ? AND duration = ?
            `
        )
            .bind(mergedScore, name, scope.scopeValue)
            .run()
        if (previousEntry && previousName && previousName !== name) {
            await env.DB.prepare(
                `
                DELETE FROM leaderboard_entries
                WHERE player_name = ? AND duration = ?
                `
            )
                .bind(previousName, scope.scopeValue)
                .run()
        }
    } else if (previousEntry && previousName && previousName !== name) {
        await env.DB.prepare(
            `
            UPDATE leaderboard_entries
            SET player_name = ?, score = ?, achieved_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
            WHERE player_name = ? AND duration = ?
            `
        )
            .bind(name, mergedScore, previousName, scope.scopeValue)
            .run()
    } else {
        await env.DB.prepare(
            `
            INSERT INTO leaderboard_entries (player_name, duration, score)
            VALUES (?, ?, ?)
            `
        )
            .bind(name, scope.scopeValue, mergedScore)
            .run()
    }

    const rankOrder = scope.ascending ? "score ASC, achieved_at ASC, id ASC" : "score DESC, achieved_at ASC, id ASC"
    const rankRow = await env.DB.prepare(
        `
        WITH ranked AS (
            SELECT
                player_name,
                ROW_NUMBER() OVER (ORDER BY ${rankOrder}) AS rank
            FROM leaderboard_entries
            WHERE duration = ?
        )
        SELECT rank
        FROM ranked
        WHERE player_name = ?
        LIMIT 1
        `
    )
        .bind(scope.scopeValue, name)
        .first<{ rank: number }>()

    return json({
        accepted: true,
        top10: (rankRow?.rank ?? 9999) <= TOP_LIMIT,
        rank: rankRow?.rank ?? null
    })
}

function mergeScores(ascending: boolean, existing: number | null, previous: number | null, incoming: number): number {
    const candidates = [existing, previous, incoming].filter((value): value is number => value != null)
    if (candidates.length == 0) {
        return incoming
    }
    return ascending ? Math.min(...candidates) : Math.max(...candidates)
}

function resolveScopeFromQuery(url: URL): { scopeValue: number; ascending: boolean; maxScore: number } | null {
    const durationValue = url.searchParams.get("duration")
    if (durationValue != null) {
        const duration = Number(durationValue)
        if (!ALLOWED_DURATIONS.has(duration)) {
            return null
        }
        return { scopeValue: duration, ascending: false, maxScore: MAX_SCORE_BY_DURATION[duration] }
    }

    const levelValue = url.searchParams.get("level")
    if (levelValue != null) {
        const level = Number(levelValue)
        if (!Number.isInteger(level) || level < STORY_LEVEL_MIN || level > STORY_LEVEL_MAX) {
            return null
        }
        return { scopeValue: STORY_SCOPE_OFFSET + level, ascending: true, maxScore: MAX_STORY_TIME_SCORE }
    }

    return null
}

function resolveScopeFromPayload(payload: SubmissionPayload): { scopeValue: number; ascending: boolean; maxScore: number } | null {
    if (payload.duration != null) {
        const duration = Number(payload.duration)
        if (!ALLOWED_DURATIONS.has(duration)) {
            return null
        }
        return { scopeValue: duration, ascending: false, maxScore: MAX_SCORE_BY_DURATION[duration] }
    }

    if (payload.level != null) {
        const level = Number(payload.level)
        if (!Number.isInteger(level) || level < STORY_LEVEL_MIN || level > STORY_LEVEL_MAX) {
            return null
        }
        return { scopeValue: STORY_SCOPE_OFFSET + level, ascending: true, maxScore: MAX_STORY_TIME_SCORE }
    }

    return null
}

function sanitizeName(value: unknown): string | null {
    if (typeof value !== "string") {
        return null
    }

    const normalized = value
        .trim()
        .replace(/\s+/g, " ")
        .replace(/[^A-Za-z0-9 _.-]/g, "")
        .slice(0, MAX_NAME_LENGTH)

    if (normalized.length < 2) {
        return null
    }

    const lower = normalized.toLowerCase()
    if (BLOCKED_NAME_PARTS.some(part => lower.includes(part))) {
        return null
    }

    return normalized
}

async function enforceRateLimit(request: Request, env: Env, action: keyof typeof RATE_LIMITS): Promise<void> {
    const ip = request.headers.get("CF-Connecting-IP") ?? "unknown"
    const ipHash = await sha256(ip)
    const { windowSeconds, maxRequests } = RATE_LIMITS[action]
    const now = Math.floor(Date.now() / 1000)
    const bucketStart = now - (now % windowSeconds)
    const rateKey = `${action}:${bucketStart}:${ipHash}`

    const current = await env.DB.prepare(
        `
        SELECT request_count
        FROM request_rate_limits
        WHERE rate_key = ?
        LIMIT 1
        `
    )
        .bind(rateKey)
        .first<RateLimitRecord>()

    if ((current?.request_count ?? 0) >= maxRequests) {
        throw json({ error: "Rate limit exceeded" }, 429, {
            "retry-after": String(windowSeconds)
        })
    }

    await env.DB.prepare(
        `
        INSERT INTO request_rate_limits (rate_key, ip_hash, action, bucket_start, request_count)
        VALUES (?, ?, ?, ?, 1)
        ON CONFLICT(rate_key) DO UPDATE
        SET request_count = request_count + 1,
            updated_at = CURRENT_TIMESTAMP
        `
    )
        .bind(rateKey, ipHash, action, bucketStart)
        .run()

    await env.DB.prepare(
        `
        DELETE FROM request_rate_limits
        WHERE bucket_start < ?
        `
    )
        .bind(now - windowSeconds * 4)
        .run()
}

async function sha256(input: string): Promise<string> {
    const bytes = new TextEncoder().encode(input)
    const digest = await crypto.subtle.digest("SHA-256", bytes)
    return [...new Uint8Array(digest)].map(byte => byte.toString(16).padStart(2, "0")).join("")
}

function json(payload: unknown, status = 200, extraHeaders: Record<string, string> = {}): Response {
    return withCors(
        new Response(JSON.stringify(payload), {
            status,
            headers: {
                "content-type": "application/json; charset=utf-8",
                "cache-control": "no-store",
                "x-content-type-options": "nosniff",
                ...extraHeaders
            }
        })
    )
}

function withCors(response: Response): Response {
    response.headers.set("Access-Control-Allow-Origin", "*")
    response.headers.set("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
    response.headers.set("Access-Control-Allow-Headers", "Content-Type")
    return response
}
