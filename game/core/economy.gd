class_name Economy
extends RefCounted
## Every coin amount, hint price and star rule in one place.

const START_COINS: int = 150
## First clear of a level.
const LEVEL_REWARD: int = 5
## Paid for each star earned for the first time (so improving 1★ -> 3★ pays 10 more).
const STAR_REWARD: int = 5
## Clearing all 40 levels of a chapter.
const CHAPTER_BONUS: int = 100
const DAILY_REWARD: int = 30
const STREAK_BONUS_PER_DAY: int = 5
const STREAK_BONUS_CAP_DAYS: int = 6

## Free hints each day, refilled at local midnight (Supporters get more).
const FREE_HINTS: int = 3
const SUPPORTER_FREE_HINTS: int = 6
## A hint once the free ones are used up.
const HINT_COST: int = 30
## One more heart after running out, instead of starting again.
const HEART_COST: int = 40
## "Free coins" videos in the shop.
const VIDEO_COINS: int = 25
const VIDEO_COINS_PER_DAY: int = 5
## Level keys from videos.
const VIDEO_KEYS_PER_DAY: int = 5
## Chapter keys (open a whole locked chapter) from videos.
const VIDEO_CHAPTER_KEYS_PER_DAY: int = 1
## Cosmetic pack trial from a video.
const TRIAL_SECONDS: int = 3600


## ★★★ with no bumps, ★★ with one, ★ with more.
static func stars_for(bounces: int) -> int:
	if bounces <= 0:
		return 3
	if bounces == 1:
		return 2
	return 1


## Coins for clearing a daily on day `streak` of a streak (streak >= 1).
static func daily_reward(streak: int) -> int:
	return DAILY_REWARD + STREAK_BONUS_PER_DAY * clampi(streak - 1, 0, STREAK_BONUS_CAP_DAYS)
