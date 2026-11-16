class_name Translit
extends RefCounted
## Writes a name typed in English letters in Hindi letters:
## "Kishan" → "किशन", "Ganga Mill" → "गंगा मिल", "Suneel" → "सुनील".
## Long vowels: aa, ee, oo (Raamu → रामू). A capital T, D, N or R inside a
## word gives ट, ड, ण, ड़ (PinTu → पिंटू). Numbers and other signs stay as they are.

const CONS := {
	"ksh": "क्ष", "chh": "छ", "kh": "ख", "gh": "घ", "ch": "च", "jh": "झ",
	"th": "थ", "dh": "ध", "ph": "फ", "bh": "भ", "sh": "श", "ck": "क",
	"Th": "ठ", "Dh": "ढ",
	"x": "क्ष", "k": "क", "g": "ग", "c": "क", "j": "ज", "t": "त", "d": "द",
	"n": "न", "p": "प", "f": "फ", "b": "ब", "m": "म", "y": "य", "r": "र",
	"l": "ल", "v": "व", "w": "व", "s": "स", "h": "ह", "z": "ज़", "q": "क",
	"T": "ट", "D": "ड", "N": "ण", "R": "ड़",
}
# latin: [on its own, after a consonant]
const VOWELS := {
	"aa": ["आ", "ा"], "ai": ["ऐ", "ै"], "au": ["औ", "ौ"], "ou": ["औ", "ौ"],
	"ee": ["ई", "ी"], "ii": ["ई", "ी"], "oo": ["ऊ", "ू"], "uu": ["ऊ", "ू"],
	"a": ["अ", ""], "i": ["इ", "ि"], "u": ["उ", "ु"], "e": ["ए", "े"], "o": ["ओ", "ो"],
}
# Common names and words spelled the usual Hindi way (when no Hindi spelling is given).
const WORDS := {
	"ajay": "अजय", "akash": "आकाश", "amit": "अमित", "anand": "आनंद", "anil": "अनिल", "arjun": "अर्जुन",
	"arvind": "अरविंद", "ashish": "आशीष", "ashok": "अशोक", "bablu": "बबलू", "babu": "बाबू", "bharat": "भरत",
	"bhola": "भोला", "chauhan": "चौहान", "chhotu": "छोटू", "chotu": "छोटू", "das": "दास", "deepak": "दीपक",
	"devendra": "देवेंद्र", "dharmendra": "धर्मेंद्र", "dilip": "दिलीप", "dinesh": "दिनेश", "dubey": "दुबे", "ganesh": "गणेश",
	"ganga": "गंगा", "gaurav": "गौरव", "geeta": "गीता", "golu": "गोलू", "gopal": "गोपाल", "gupta": "गुप्ता",
	"hari": "हरि", "jagdish": "जगदीश", "jamuna": "जमुना", "jitendra": "जितेंद्र", "kailash": "कैलाश", "kallu": "कल्लू",
	"kamal": "कमल", "kamla": "कमला", "kaveri": "कावेरी", "kishan": "किशन", "kishor": "किशोर", "krishan": "कृष्ण",
	"krishna": "कृष्ण", "kumar": "कुमार", "kushwaha": "कुशवाहा", "lakshman": "लक्ष्मण", "lakshmi": "लक्ष्मी", "lal": "लाल",
	"lalit": "ललित", "laxman": "लक्ष्मण", "madan": "मदन", "mahendra": "महेंद्र", "mahesh": "महेश", "manoj": "मनोज",
	"master": "मास्टर", "maurya": "मौर्य", "mill": "मिल", "mills": "मिल्स", "mishra": "मिश्रा", "mohan": "मोहन",
	"mohit": "मोहित", "monu": "मोनू", "mukesh": "मुकेश", "munna": "मुन्ना", "narendra": "नरेंद्र", "naresh": "नरेश",
	"narmada": "नर्मदा", "nishad": "निषाद", "nitin": "नितिन", "om": "ओम", "pal": "पाल", "pandey": "पांडे",
	"pankaj": "पंकज", "pappu": "पप्पू", "patel": "पटेल", "pawan": "पवन", "pintu": "पिंटू", "pooja": "पूजा",
	"pradeep": "प्रदीप", "prakash": "प्रकाश", "pramod": "प्रमोद", "prasad": "प्रसाद", "prem": "प्रेम", "radha": "राधा",
	"rahul": "राहुल", "raj": "राज", "rajan": "राजन", "rajeev": "राजीव", "rajendra": "राजेंद्र", "rajesh": "राजेश",
	"rajiv": "राजीव", "rajkumar": "राजकुमार", "raju": "राजू", "rakesh": "राकेश", "ram": "राम", "ramdas": "रामदास",
	"ramesh": "रमेश", "ramji": "रामजी", "ramkumar": "रामकुमार", "ramlal": "रामलाल", "ramu": "रामू", "ravi": "रवि",
	"rekha": "रेखा", "sachin": "सचिन", "sanjay": "संजय", "sanju": "संजू", "santosh": "संतोष", "satish": "सतीश",
	"savitri": "सावित्री", "shailendra": "शैलेंद्र", "shankar": "शंकर", "sharma": "शर्मा", "shiv": "शिव", "shivam": "शिवम",
	"shree": "श्री", "shri": "श्री", "shyam": "श्याम", "shyamlal": "श्यामलाल", "singh": "सिंह", "sita": "सीता",
	"sohan": "सोहन", "sonu": "सोनू", "sunil": "सुनील", "sunita": "सुनीता", "sunny": "सनी", "surendra": "सुरेंद्र",
	"suresh": "सुरेश", "tarun": "तरुण", "tiwari": "तिवारी", "umesh": "उमेश", "upendra": "उपेंद्र", "verma": "वर्मा",
	"vijay": "विजय", "vikas": "विकास", "vikram": "विक्रम", "vinod": "विनोद", "virendra": "वीरेंद्र", "yadav": "यादव",
	"yamuna": "यमुना", "yogesh": "योगेश",
}
const HALANT := "्"
const ANUSVARA := "ं"
# n / m before these sound as ं (Ganga → गंगा, Ambika → अंबिका).
const NASAL_N := ["क", "ख", "ग", "घ", "च", "छ", "ज", "झ", "ट", "ठ", "ड", "ढ", "त", "थ", "द", "ध", "क्ष"]
const NASAL_M := ["प", "फ", "ब", "भ"]

static var _cache := {}


static func to_hi(s: String) -> String:
	if _cache.has(s):
		return _cache[s]
	var out := ""
	var word := ""
	for ch in s:
		if _is_latin(ch):
			word += ch
		else:
			if word != "":
				out += _word(word)
				word = ""
			out += ch
	if word != "":
		out += _word(word)
	_cache[s] = out
	return out


static func _is_latin(ch: String) -> bool:
	var c := ch.unicode_at(0)
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122)


static func _tokens(w: String) -> Array:
	## [[kind, latin, devanagari]] where kind is "c" (consonant) or "v" (vowel).
	var toks := []
	var i := 0
	while i < w.length():
		var found := false
		for n in [3, 2, 1]:
			if i + n > w.length():
				continue
			var raw := w.substr(i, n)
			# Capital letters keep their meaning only inside a word (T → ट);
			# the first letter of a name is just a capital.
			var key := raw if i > 0 else raw.substr(0, 1).to_lower() + raw.substr(1)
			if not CONS.has(key) and not VOWELS.has(key):
				key = key.to_lower()
			if CONS.has(key):
				toks.append(["c", key.to_lower(), CONS[key]])
				i += n
				found = true
				break
			if VOWELS.has(key):
				toks.append(["v", key, VOWELS[key]])
				i += n
				found = true
				break
		if not found:
			i += 1
	return toks


static func _word(w: String) -> String:
	var lw := w.to_lower()
	if WORDS.has(lw) and (w == lw or w.substr(1) == lw.substr(1)):
		return WORDS[lw]
	var toks := _tokens(w)
	# A doubled consonant at the very end is one sound (Mill → मिल).
	var n := toks.size()
	if n >= 2 and toks[n - 1][0] == "c" and toks[n - 2][0] == "c" and toks[n - 1][2] == toks[n - 2][2]:
		toks.remove_at(n - 1)
		n -= 1
	var out := ""
	for i in n:
		var t: Array = toks[i]
		var last: bool = i == n - 1
		var prev_kind: String = toks[i - 1][0] if i > 0 else ""
		if t[0] == "v":
			var forms: Array = t[2]
			if prev_kind == "c":
				var m: String = forms[1]
				# Names ending in a / i / u end long: Ganga गंगा, Kaveri कावेरी, Raju राजू.
				if last and t[1] == "a":
					m = "ा"
				elif last and t[1] == "i":
					m = "ी"
				elif last and t[1] == "u":
					m = "ू"
				out += m
			else:
				out += forms[0]
			continue
		var next: Array = toks[i + 1] if i + 1 < n else []
		var next_is_cons: bool = not next.is_empty() and next[0] == "c"
		if next_is_cons and prev_kind == "v" and next[2] != t[2]:
			if (t[2] == "न" and next[2] in NASAL_N) or (t[2] == "म" and next[2] in NASAL_M):
				out += ANUSVARA
				continue
		out += t[2]
		if next_is_cons:
			out += HALANT
	return out
