extends Node
## Localization. English source strings are the keys; translations live in
## res://data/locale/<code>.json as {"English": "Translated"}. UIKit helpers translate
## every caption they receive, so adding a language = adding one JSON file.

signal language_changed(code: String)

const LANGUAGES := {"en": "English", "ru": "Русский"}

var current := "en"
var _translations: Dictionary = {}


func _ready() -> void:
	for code in LANGUAGES.keys():
		if code == "en":
			continue
		var path := "res://data/locale/%s.json" % code
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			push_warning("Loc: missing %s" % path)
			continue
		var json := JSON.new()
		if json.parse(f.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
			push_error("Loc: invalid JSON in %s" % path)
			continue
		var t := Translation.new()
		t.locale = code
		var d: Dictionary = json.data
		for k in d.keys():
			if not String(k).begins_with("_") and String(d[k]) != "":
				t.add_message(k, d[k])
		TranslationServer.add_translation(t)
		_translations[code] = t


static func system_language() -> String:
	return "ru" if OS.get_locale_language() in ["ru", "uk", "be", "kk"] else "en"


func apply(code: String) -> void:
	if code == "auto" or not LANGUAGES.has(code):
		code = system_language()
	var changed := code != current
	current = code
	TranslationServer.set_locale(code)
	if changed:
		language_changed.emit(code)


func message_count(code: String) -> int:
	if not _translations.has(code):
		return 0
	return (_translations[code] as Translation).get_message_count()
