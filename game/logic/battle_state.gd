class_name BattleState
extends RefCounted
## Matematik Savaşı kuralları. Oyuncu can kaybetmez; savaş her zaman kazanılabilir.
## Doğru cevap canavara 1 hasar verir. Yanlış cevapta ipucu, ikinci yanlışta çözüm
## gösterilir ve yeni soruya geçilir (ceza yok).

enum Result { CORRECT, WRONG_HINT, WRONG_REVEAL }

const MONSTER_HP := 5
const MAX_ATTEMPTS := 2

var monster_hp := MONSTER_HP
var questions_asked := 0
var first_try_correct := 0
var attempts_on_current := 0
var current: MathQuestion


func start_question(q: MathQuestion) -> void:
	current = q
	attempts_on_current = 0
	questions_asked += 1


func answer(value: int) -> Result:
	if value == current.answer:
		if attempts_on_current == 0:
			first_try_correct += 1
		monster_hp = maxi(monster_hp - 1, 0)
		return Result.CORRECT
	attempts_on_current += 1
	return Result.WRONG_HINT if attempts_on_current < MAX_ATTEMPTS else Result.WRONG_REVEAL


func is_won() -> bool:
	return monster_hp <= 0


## 1–3 yıldız: ilk denemede doğru cevap oranına göre. Kazanan herkes en az 1 yıldız alır.
func stars() -> int:
	if questions_asked == 0:
		return 1
	var ratio := float(first_try_correct) / questions_asked
	if ratio >= 0.8:
		return 3
	if ratio >= 0.5:
		return 2
	return 1
