class_name MathQuestion
extends RefCounted
## Tek bir matematik sorusu: ifade veya soru metni, doğru cevap, 4 seçenek ve öğretici ipucu.
## Cevap sayı (int) ya da kesir metni ("3/4") olabilir.

var topic := ""
var expression := ""          # İşlem sorularında ekranda görünen ifade, ör. "5 + 3 × 4"
var prompt := ""              # Metin sorularında soru cümlesi, ör. "Hangisi asal sayıdır?"
var answer: Variant = 0
var choices: Array = []
var hint_key := ""
var hint_args := {}
var meta := {}                # Soru parametreleri (görsel model, doğrulama testleri için)


func question_text() -> String:
	return prompt if not prompt.is_empty() else expression + " = ?"


func is_correct(value: Variant) -> bool:
	return typeof(value) == typeof(answer) and value == answer


func hint_text() -> String:
	return _keep_together(TranslationServer.translate(hint_key).format(hint_args))


func solution_text() -> String:
	if not prompt.is_empty():
		return TranslationServer.translate("BATTLE_SOLUTION_SHORT").format({"answer": answer})
	return _keep_together(TranslationServer.translate("BATTLE_SOLUTION").format(
		{"expr": expression, "answer": answer}))


## "25 × 10" gibi parçaların satır sonunda bölünmemesi için bölünmez boşluk kullanır.
static func _keep_together(text: String) -> String:
	const NBSP := " "
	for op in ["×", "÷", "="]:
		text = text.replace(" %s " % op, NBSP + op + NBSP)
	return text
