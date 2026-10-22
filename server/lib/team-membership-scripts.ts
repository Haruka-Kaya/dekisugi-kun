/** Membership checks and writes share one Redis execution, including leave/cooldown. */
export const JOIN_TEAM_SCRIPT = `
local teamId, mid = ARGV[1], ARGV[2]
local now, limit, ttl = tonumber(ARGV[3]), tonumber(ARGV[4]), tonumber(ARGV[5])
if redis.call('HGET', KEYS[1], 'teamId') ~= teamId then
  return {0, 'unknown_code'}
end
local expires = tonumber(redis.call('HGET', KEYS[1], 'expiresAt') or '0')
if redis.call('HGET', KEYS[1], 'revoked') == '1' or not expires or expires <= now then
  return {0, 'expired'}
end
local name = redis.call('HGET', KEYS[2], 'name')
if not name or name == '' then return {0, 'unknown_code'} end
local periodId = redis.call('HGET', KEYS[2], 'periodId') or ''
local periodStart = redis.call('HGET', KEYS[2], 'periodStart') or ''
local periodEnd = redis.call('HGET', KEYS[2], 'periodEnd') or ''
local mine = redis.call('GET', KEYS[4])
local cool = redis.call('GET', KEYS[5])
local size = redis.call('SCARD', KEYS[3])
local already = redis.call('SISMEMBER', KEYS[3], mid)
-- Never treat an inconsistent old membership as permission to enter two teams.
if already == 1 then
  if mine and mine ~= teamId then return {0, 'in_other_team'} end
  return {1, name, periodId, periodStart, periodEnd, size, already}
end
if cool and (not tonumber(cool) or tonumber(cool) > now) then return {0, 'cooldown'} end
if mine and mine ~= teamId then return {0, 'in_other_team'} end
if size >= limit then return {0, 'team_full'} end
size = size + redis.call('SADD', KEYS[3], mid)
redis.call('EXPIRE', KEYS[3], ttl)
redis.call('SET', KEYS[4], teamId, 'EX', ttl)
return {1, name, periodId, periodStart, periodEnd, size, already}
`

export const LEAVE_TEAM_SCRIPT = `
local mid, teamId = ARGV[1], ARGV[2]
local mine = redis.call('GET', KEYS[2])
if mine and mine ~= teamId then return 0 end
if redis.call('SISMEMBER', KEYS[1], mid) ~= 1 then return 0 end
redis.call('SREM', KEYS[1], mid)
redis.call('DEL', KEYS[3])
redis.call('DEL', KEYS[2])
redis.call('SET', KEYS[4], ARGV[3], 'EX', ARGV[4])
return 1
`

/** The handler has already checked dates, daily caps, and actual session counts. */
export const CONTRIBUTE_TEAM_SCRIPT = `
local mid, teamId, periodId, day = ARGV[1], ARGV[2], ARGV[3], ARGV[4]
local value, ttl = tonumber(ARGV[5]), tonumber(ARGV[6])
if redis.call('GET', KEYS[1]) ~= teamId
  or redis.call('SISMEMBER', KEYS[2], mid) ~= 1
  or redis.call('HGET', KEYS[5], 'periodId') ~= periodId then
  return {0, 'not_in_team'}
end
local previous = tonumber(redis.call('HGET', KEYS[3], day) or '0')
if not previous then return redis.error_reply('Invalid stored contribution') end
local delta = value - previous
if delta <= 0 then return {1, previous, 0} end
-- HINCRBY can reject a corrupt/overflowed total: do it before altering the
-- individual day. HGET above already checked the other hash's type.
redis.call('HINCRBY', KEYS[4], 'total', delta)
redis.call('HSET', KEYS[3], day, ARGV[5])
redis.call('EXPIRE', KEYS[3], ttl)
redis.call('EXPIRE', KEYS[4], ttl)
return {1, value, delta}
`
