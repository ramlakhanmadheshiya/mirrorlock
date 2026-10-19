class_name ChapterIntroCard
extends HowToCard
## The first time a chapter's level 1 opens: a card with the chapter's new idea,
## a live board showing it, and Got it. (Reflect has the hands-on tutorial instead.)

const CHAPTER_PAGES: Dictionary = {
	"reflect": "basics", "horizon": "horizon", "stones": "stones", "solo": "lonely", "slant": "diagonal",
	"vault": "locks", "kaleido": "kaleido", "turn": "turn", "finale": "finale",
}

var chapter_idx: int = 1


func build() -> void:
	name = "ChapterIntro"
	var ch: Dictionary = Catalog.chapter(chapter_idx)
	pages = [str(CHAPTER_PAGES.get(str(ch.get("id", "")), "basics"))]
	heading = "New in %s" % ch.get("name", "")
	super.build()
