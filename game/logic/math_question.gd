class_name MathQuestion
extends RefCounted
## Tek bir matematik sorusu: ifade, doğru cevap, 4 seçenek ve öğretici ipucu.

var topic := ""
var expression := ""          # Ekranda görünen ifade, ör. "5 + 3 × 4"
var answer := 0
var choices: Array[int] = []
var hint_key := ""
var hint_args := {}


func hint_text() -> String:
	return _keep_together(TranslationServer.translate(hint_key).format(hint_args))


func solution_text() -> String:
	return _keep_together(TranslationServer.translate("BATTLE_SOLUTION").format(
		{"expr": expression, "answer": answer}))


## "25 × 10" gibi parçaların satır sonunda bölünmemesi için bölünmez boşluk kullanır.
static func _keep_together(text: String) -> String:
	const NBSP := " "
	for op in ["×", "÷", "="]:
		text = text.replace(" %s " % op, NBSP + op + NBSP)
	return text
