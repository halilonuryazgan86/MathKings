class_name Fraction
extends RefCounted
## Kesir yardımcıları. Kesirler "pay/payda" metni olarak taşınır (ör. "3/4").


static func gcd(a: int, b: int) -> int:
	a = absi(a)
	b = absi(b)
	while b != 0:
		var t := b
		b = a % b
		a = t
	return maxi(a, 1)


static func text(num: int, den: int) -> String:
	return "%d/%d" % [num, den]


static func simplified(num: int, den: int) -> String:
	var g := gcd(num, den)
	return text(num / g, den / g)


static func parse(s: String) -> Vector2i:
	var parts := s.split("/")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or int(parts[1]) == 0:
		return Vector2i(0, 0)
	return Vector2i(int(parts[0]), int(parts[1]))


## Değer olarak eşit mi (2/4 = 1/2)?
static func same_value(a: String, b: String) -> bool:
	var x := parse(a)
	var y := parse(b)
	return x.y != 0 and y.y != 0 and x.x * y.y == y.x * x.y


static func compare(a: String, b: String) -> int:
	var x := parse(a)
	var y := parse(b)
	return signi(x.x * y.y - y.x * x.y)
