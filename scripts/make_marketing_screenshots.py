#!/usr/bin/env python3
"""App Store 마케팅 스크린샷: 원본 캡처 + 헤드라인 → HTML → 헤드리스 Chrome (appstore-assets 스킬).

사용법: python3 scripts/make_marketing_screenshots.py [언어 ...]   (없으면 전부)

자리
  docs/screenshots/raw/<언어>/NN-….png          원본 캡처 (1320x2868, 스토어에 안 올라감)
  docs/screenshots/marketing/<로케일>/NN-….png   제출본 1242x2688 — DeployBar 가 이 폴더를 그대로 올린다
슬라이드마다 배치(layout)를 달리한다: hero-bleed · left-text · text-bottom · flat-rotate · dark
"""
import subprocess, sys, pathlib, tempfile, time

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "docs" / "screenshots" / "raw"
OUT = ROOT / "docs" / "screenshots" / "marketing"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1242, 2688   # 이 계정의 아이폰 제출 규격

# 앱 언어 → App Store 로케일
STORE = {"ko": "ko", "en": "en-US", "en-GB": "en-GB", "zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant", "ja": "ja", "ru": "ru", "es": "es-ES", "de": "de-DE", "fr": "fr-FR", "it": "it", "pt-BR": "pt-BR", "th": "th", "vi": "vi", "cs": "cs", "da": "da", "el": "el", "fi": "fi", "id": "id", "nb": "no", "nl": "nl-NL", "pl": "pl", "sv": "sv-SE", "tr": "tr"}

# 파일 · 배치 · 언어별 (헤드라인, 보조 문장)
SHOTS = [
    ("01-home.png",     "hero-bleed",  {"ko": ("끊긴 생각을<br>그대로 이어요", "멈춘 자리의 질문부터 다시 시작해요"), "en": ("Pick up your<br>paused thoughts", "Start again from the question you left"), "en-GB": ("Pick up your<br>paused thoughts", "Start again from the question you left"), "zh-Hans": ("把中断的想法<br>原样接上", "从停下的那个问题重新开始"), "zh-Hant": ("把中斷的想法<br>原樣接上", "從停下的那個問題重新開始"), "ja": ("止まった考えを<br>そのまま続ける", "止まった場所の問いからもう一度はじめる"), "ru": ("Продолжайте мысль<br>с того же места", "Начните снова с вопроса, на котором остановились"), "es": ("Retoma tus ideas<br>donde las dejaste", "Empieza de nuevo desde la pregunta que dejaste"), "de": ("Gedanken genau dort<br>weiterführen", "Starte wieder bei der Frage, die du hinterlassen hast"), "fr": ("Reprenez vos idées<br>là où vous les avez laissées", "Repartez de la question que vous aviez laissée"), "it": ("Riprendi i pensieri<br>da dove li hai lasciati", "Riparti dalla domanda che avevi lasciato"), "pt-BR": ("Retome suas ideias<br>de onde parou", "Recomece da pergunta que você deixou"), "th": ("ต่อความคิดที่หยุดไว้<br>ได้ทันที", "เริ่มใหม่จากคำถามที่ทิ้งไว้"), "vi": ("Nối tiếp suy nghĩ<br>ngay chỗ đã dừng", "Bắt đầu lại từ câu hỏi bạn đã để lại"), "cs": ("Navažte na myšlenky<br>tam, kde jste skončili", "Začněte znovu otázkou, kterou jste nechali"), "da": ("Fortsæt dine tanker,<br>hvor du slap", "Start igen ved det spørgsmål, du efterlod"), "el": ("Συνέχισε τις σκέψεις<br>απ’ όπου σταμάτησες", "Ξεκίνα ξανά από την ερώτηση που άφησες"), "fi": ("Jatka ajatuksia<br>siitä, mihin jäit", "Aloita uudelleen kysymyksestä, jonka jätit"), "id": ("Lanjutkan pikiran<br>dari tempat berhenti", "Mulai lagi dari pertanyaan yang kamu tinggalkan"), "nb": ("Fortsett tankene<br>der du slapp", "Start igjen ved spørsmålet du la igjen"), "nl": ("Zet je gedachten voort<br>waar je stopte", "Begin opnieuw bij de vraag die je achterliet"), "pl": ("Kontynuuj myśli<br>od tego miejsca", "Zacznij od pytania, które zostawiłeś"), "sv": ("Fortsätt tankarna<br>där du slutade", "Börja om vid frågan du lämnade"), "tr": ("Düşüncelerini kaldığın<br>yerden sürdür", "Bıraktığın sorudan yeniden başla")}),
    ("02-continue.png", "left-text",   {"ko": ("어디까지 생각했는지<br>먼저 보여줘요", "핵심과 직전 생각을 보고 바로 이어 써요"), "en": ("See where you<br>left off first", "Read the key point and last thought, then keep writing"), "en-GB": ("See where you<br>left off first", "Read the key point and last thought, then carry on"), "zh-Hans": ("先告诉你<br>想到了哪里", "看着要点和上一条想法，马上接着写"), "zh-Hant": ("先告訴你<br>想到了哪裡", "看著重點和上一則想法，馬上接著寫"), "ja": ("どこまで考えたか<br>まず見せます", "要点と直前の考えを見て、すぐ書き足せます"), "ru": ("Сначала видно,<br>до чего вы дошли", "Главное и последняя мысль — и можно писать дальше"), "es": ("Mira primero<br>hasta dónde llegaste", "Lee lo esencial y tu última idea, y sigue escribiendo"), "de": ("Zuerst siehst du,<br>wo du warst", "Kernpunkt und letzter Gedanke – und gleich weiterschreiben"), "fr": ("Voyez d’abord<br>où vous en étiez", "L’essentiel et la dernière idée, puis vous continuez"), "it": ("Vedi subito<br>a che punto eri", "Leggi l’essenziale e l’ultimo pensiero, poi continua"), "pt-BR": ("Veja primeiro<br>até onde você foi", "Leia o essencial e a última ideia e continue escrevendo"), "th": ("ดูก่อนว่า<br>คิดมาถึงไหน", "ดูประเด็นหลักและความคิดล่าสุด แล้วเขียนต่อได้เลย"), "vi": ("Xem trước<br>bạn nghĩ đến đâu", "Đọc ý chính và suy nghĩ gần nhất rồi viết tiếp"), "cs": ("Nejdřív uvidíte,<br>kam jste došli", "Podstata a poslední myšlenka, pak píšete dál"), "da": ("Se først,<br>hvor du var nået til", "Læs kernen og din seneste tanke, og skriv videre"), "el": ("Δες πρώτα<br>πού έφτασες", "Κύριο σημείο και τελευταία σκέψη, και γράψε παρακάτω"), "fi": ("Näet ensin,<br>mihin ehdit", "Ydin ja viimeisin ajatus, sitten jatkat kirjoittamista"), "id": ("Lihat dulu<br>sampai mana kamu", "Baca intinya dan pikiran terakhir, lalu tulis lagi"), "nb": ("Se først<br>hvor langt du kom", "Les kjernen og siste tanke, og skriv videre"), "nl": ("Zie eerst<br>waar je gebleven was", "Lees de kern en je laatste gedachte en schrijf verder"), "pl": ("Najpierw zobacz,<br>dokąd dotarłeś", "Sedno i ostatnia myśl – i piszesz dalej"), "sv": ("Se först<br>hur långt du kom", "Läs kärnan och senaste tanken och skriv vidare"), "tr": ("Önce nereye kadar<br>geldiğini gör", "Özet noktayı ve son düşünceyi gör, yazmaya devam et")}),
    ("03-bridge.png",   "text-bottom", {"ko": ("기세가 있을 때<br>문장을 끊어 두세요", "다음에 열면 그 질문에서 다시 출발해요"), "en": ("Stop while you’re<br>on a roll", "Next time you open it, restart from that question"), "en-GB": ("Stop while you’re<br>on a roll", "Next time you open it, restart from that question"), "zh-Hans": ("趁思路正顺<br>留下一句话", "下次打开，就从那个问题出发"), "zh-Hant": ("趁思緒正順<br>留下一句話", "下次打開，就從那個問題出發"), "ja": ("勢いのあるうちに<br>一文を残そう", "次に開くと、その問いから再スタート"), "ru": ("Остановитесь<br>на подъёме", "В следующий раз начнёте с этого вопроса"), "es": ("Para mientras<br>vas lanzado", "La próxima vez, retomas desde esa pregunta"), "de": ("Hör auf,<br>solange es läuft", "Beim nächsten Öffnen startest du bei dieser Frage"), "fr": ("Arrêtez-vous<br>en plein élan", "À la prochaine ouverture, vous repartez de cette question"), "it": ("Fermati finché<br>sei ispirato", "La prossima volta riparti da quella domanda"), "pt-BR": ("Pare enquanto<br>está no embalo", "Da próxima vez, recomece dessa pergunta"), "th": ("หยุดตอน<br>กำลังมีไฟ", "เปิดครั้งหน้า เริ่มจากคำถามนั้นต่อได้ทันที"), "vi": ("Dừng khi<br>đang hứng khởi", "Lần sau mở ra, bắt đầu lại từ câu hỏi đó"), "cs": ("Skončete,<br>dokud to jde", "Až příště otevřete, začnete u té otázky"), "da": ("Stop,<br>mens det går godt", "Næste gang starter du ved det spørgsmål"), "el": ("Σταμάτα όσο<br>έχεις φόρα", "Την επόμενη φορά ξεκινάς από εκείνη την ερώτηση"), "fi": ("Lopeta, kun<br>vauhti vielä kantaa", "Ensi kerralla aloitat tuosta kysymyksestä"), "id": ("Berhenti saat<br>sedang lancar", "Saat dibuka lagi, mulai dari pertanyaan itu"), "nb": ("Stopp mens<br>det går bra", "Neste gang starter du ved det spørsmålet"), "nl": ("Stop als het<br>lekker loopt", "De volgende keer begin je bij die vraag"), "pl": ("Przerwij, gdy<br>idzie dobrze", "Następnym razem zaczniesz od tego pytania"), "sv": ("Sluta medan<br>det flyter på", "Nästa gång börjar du vid den frågan"), "tr": ("Akıştayken<br>dur", "Bir sonraki açışında o sorudan devam edersin")}),
    ("04-thread.png",   "flat-rotate", {"ko": ("메모가 핵심이 되기까지<br>한눈에", "메모, 정리, 핵심, 요약으로 생각을 다듬어요"), "en": ("From note to key<br>point at a glance", "Refine thoughts: note, refined, key point, summary"), "en-GB": ("From note to key<br>point at a glance", "Refine thoughts: note, refined, key point, summary"), "zh-Hans": ("从备忘到要点<br>一目了然", "备忘、整理、要点、总结，逐步提炼想法"), "zh-Hant": ("從備忘到重點<br>一目了然", "備忘、整理、重點、摘要，逐步提煉想法"), "ja": ("メモが要点になるまで<br>ひと目で", "メモ・整理・要点・要約で考えを磨きます"), "ru": ("От заметки до главного<br>с первого взгляда", "Заметка, разобрано, главное, итог — мысль зреет"), "es": ("De la nota a lo esencial<br>de un vistazo", "Nota, ordenado, clave y resumen para afinar tus ideas"), "de": ("Von der Notiz zum<br>Kernpunkt im Blick", "Notiz, geordnet, Kernpunkt, Zusammenfassung"), "fr": ("De la note à l’essentiel<br>d’un coup d’œil", "Note, trié, essentiel, résumé : affinez vos idées"), "it": ("Dall’appunto all’essenziale<br>a colpo d’occhio", "Appunto, ordinato, chiave e riassunto per rifinire i pensieri"), "pt-BR": ("Da nota ao essencial<br>num relance", "Nota, organizado, essencial e resumo para refinar ideias"), "th": ("จากโน้ตสู่ประเด็นหลัก<br>ในพริบตา", "โน้ต จัดระเบียบ ประเด็นหลัก สรุป กลั่นความคิด"), "vi": ("Từ ghi chú đến ý chính<br>trong một cái nhìn", "Ghi chú, sắp xếp, ý chính, tóm tắt để chắt lọc"), "cs": ("Od poznámky k podstatě<br>na první pohled", "Poznámka, utříděno, podstata, shrnutí"), "da": ("Fra note til kerne<br>med ét blik", "Note, ordnet, kernen og resumé – udfin dine tanker"), "el": ("Από τη σημείωση στο κύριο<br>σημείο με μια ματιά", "Σημείωση, τακτοποιημένο, κύριο σημείο, περίληψη"), "fi": ("Muistiinpanosta ytimeen<br>yhdellä silmäyksellä", "Muistiinpano, järjestetty, ydin, tiivistelmä"), "id": ("Dari catatan ke inti<br>sekali lihat", "Catatan, tertata, inti, ringkasan untuk menajamkan pikiran"), "nb": ("Fra notat til kjerne<br>med ett blikk", "Notat, ordnet, kjernen og sammendrag"), "nl": ("Van notitie tot kern<br>in één oogopslag", "Notitie, geordend, kern, samenvatting"), "pl": ("Od notatki do sedna<br>jednym rzutem oka", "Notatka, uporządkowane, sedno, podsumowanie"), "sv": ("Från anteckning till kärna<br>med en blick", "Anteckning, ordnat, kärnan och sammanfattning"), "tr": ("Nottan özet noktaya<br>tek bakışta", "Not, düzenlendi, özet nokta, özet")}),
    ("05-dump.png",     "dark",        {"ko": ("머릿속 생각을<br>일단 다 꺼내요", "한 줄씩 적어 두면 나중에 생각 스레드가 돼요"), "en": ("Dump everything<br>on your mind", "Jot one line at a time and turn it into a thread later"), "en-GB": ("Dump everything<br>on your mind", "Jot down one line at a time and turn it into a thread later"), "zh-Hans": ("先把脑中的想法<br>全部倒出来", "一行一行写下，之后就能变成思考线程"), "zh-Hant": ("先把腦中的想法<br>全部倒出來", "一行一行寫下，之後就能變成思考串"), "ja": ("頭の中の考えを<br>まず全部書き出す", "1行ずつ書けば、あとで思考スレッドに"), "ru": ("Выпишите всё,<br>что в голове", "Строка за строкой — потом станет цепочкой мыслей"), "es": ("Vuelca todo lo que<br>tienes en la cabeza", "Escribe línea a línea y conviértelo en un hilo después"), "de": ("Alles aus dem<br>Kopf schütten", "Zeile für Zeile aufschreiben, später zum Faden machen"), "fr": ("Videz tout ce qui<br>vous trotte dans la tête", "Ligne par ligne, puis un fil de pensée plus tard"), "it": ("Svuota tutto quello<br>che hai in testa", "Scrivi una riga alla volta, poi fanne un filo di pensiero"), "pt-BR": ("Despeje tudo que<br>está na sua cabeça", "Escreva linha a linha e vire um fio de pensamento depois"), "th": ("ระบายความคิด<br>ในหัวออกมาให้หมด", "เขียนทีละบรรทัด แล้วค่อยเปลี่ยนเป็นสายความคิด"), "vi": ("Trút hết suy nghĩ<br>trong đầu ra", "Viết từng dòng, sau đó thành mạch suy nghĩ"), "cs": ("Vysypte všechno,<br>co máte v hlavě", "Řádek po řádku, později z toho bude vlákno úvah"), "da": ("Tøm hovedet<br>for alt", "Skriv én linje ad gangen og gør det til en tråd senere"), "el": ("Άδειασε ό,τι έχεις<br>στο μυαλό", "Μία γραμμή τη φορά, και αργότερα γίνεται νήμα σκέψης"), "fi": ("Tyhjennä kaikki,<br>mitä mielessä on", "Yksi rivi kerrallaan, myöhemmin ajatusketjuksi"), "id": ("Tuangkan semua yang<br>ada di kepalamu", "Tulis satu baris demi satu, lalu jadikan utas pikiran"), "nb": ("Tøm hodet<br>for alt", "Skriv én linje om gangen og gjør det til en tråd senere"), "nl": ("Maak je hoofd<br>helemaal leeg", "Schrijf regel voor regel en maak er later een draad van"), "pl": ("Wyrzuć wszystko,<br>co masz w głowie", "Wiersz po wierszu, a potem zrób z tego wątek myśli"), "sv": ("Töm huvudet<br>på allt", "Skriv en rad i taget och gör det till en tråd senare"), "tr": ("Aklındaki her şeyi<br>dök", "Satır satır yaz, sonra düşünce dizisine dönüştür")}),
]

# 색은 헤더·검색 결과 그림(make_creative_assets.py)과 맞춘다.
THEME = dict(bg="radial-gradient(ellipse at 50% 40%, #221a44 0%, #15112c 55%, #0d0b1e 100%)", ink="#f4f2fb",
             sub="#a19cbf", dark_bg="#0d0b1e", dark_ink="#FFB067", dark_sub="#a19cbf", frame="#17151f",
             rim="#3a3550", glow="rgba(255,149,51,.28)")

BASE_CSS = """
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:%(W)dpx; height:%(H)dpx; overflow:hidden; }
body { background:%(bg)s; font-family:-apple-system, "Apple SD Gothic Neo", "Hiragino Sans", sans-serif; position:relative; }
.headline { font-size:96px; font-weight:800; color:%(ink)s; letter-spacing:-2px; line-height:1.22; text-wrap:balance; }
.sub { font-size:50px; font-weight:500; color:%(sub)s; letter-spacing:-1px; line-height:1.35; text-wrap:balance; }
:lang(ko) .headline, :lang(ko) .sub { word-break:keep-all; }
.phone { background:%(frame)s; border-radius:112px; border:3px solid %(rim)s; padding:24px;
  box-shadow: 60px 90px 120px rgba(0,0,0,.24), 20px 30px 50px rgba(0,0,0,.14); }
.phone img { width:100%%; display:block; border-radius:89px; }
"""

LAYOUTS = {
    "hero-bleed": """
.headline { text-align:center; margin-top:270px; padding:0 70px; }
.sub { text-align:center; margin-top:46px; padding:0 80px; }
.wrap { display:flex; justify-content:center; margin-top:130px; }
.phone { width:970px; }
""",
    "left-text": """
.headline { text-align:left; margin:280px 90px 0 105px; }
.sub { text-align:left; margin:44px 90px 0 109px; }
.wrap { perspective:2600px; perspective-origin:30% 30%; position:absolute; left:290px; top:960px; }
.phone { width:815px; transform:rotateY(16deg) rotateX(2deg); }
""",
    "text-bottom": """
.wrap { perspective:2800px; perspective-origin:50% 40%; display:flex; justify-content:center; margin-top:160px; }
.phone { width:850px; transform:rotateY(-10deg) rotateX(2deg); }
.headline { text-align:center; margin-top:110px; padding:0 70px; }
.sub { text-align:center; margin-top:44px; padding:0 80px; }
""",
    "flat-rotate": """
.headline { text-align:center; margin-top:250px; padding:0 70px; }
.sub { text-align:center; margin-top:46px; padding:0 80px; }
.wrap { position:absolute; left:115px; top:980px; }
.phone { width:980px; transform:rotate(-6deg); }
""",
    "dark": """
body { background:%(dark_bg)s; }
.headline { color:%(dark_ink)s; text-align:center; margin-top:270px; padding:0 70px; }
.sub { color:%(dark_sub)s; text-align:center; margin-top:46px; padding:0 80px; }
.wrap { display:flex; justify-content:center; margin-top:130px; }
.phone { width:900px; border-color:#48484e; box-shadow: 0 0 160px %(glow)s, 40px 70px 110px rgba(0,0,0,.55); }
""",
}

TEXT_FIRST = '<div class="headline">{h}</div><div class="sub">{s}</div><div class="wrap"><div class="phone"><img src="{img}"></div></div>'
PHONE_FIRST = '<div class="wrap"><div class="phone"><img src="{img}"></div></div><div class="headline">{h}</div><div class="sub">{s}</div>'
HTML = '<!doctype html><html lang="{lang}"><head><meta charset="utf-8"><style>{css}</style></head><body>{body}</body></html>'


def raw_for(lang, fname):
    p = RAW / lang / fname
    return p if p.exists() else RAW / fname


def main(langs):
    tmp = pathlib.Path(tempfile.mkdtemp())
    vals = dict(THEME, W=W, H=H)
    for lang in langs:
        out_dir = OUT / STORE[lang]
        out_dir.mkdir(parents=True, exist_ok=True)
        for fname, layout, texts in SHOTS:
            h, s = texts[lang]
            src = raw_for(lang, fname)
            assert src.exists(), f"원본 없음: {src}"
            tpl = PHONE_FIRST if layout == "text-bottom" else TEXT_FIRST
            css = BASE_CSS % vals + LAYOUTS[layout] % vals if "%(" in LAYOUTS[layout] else BASE_CSS % vals + LAYOUTS[layout]
            html = tmp / f"{lang}-{fname}.html"
            html.write_text(HTML.format(lang=lang, css=css, body=tpl.format(h=h, s=s, img=src.as_uri())), encoding="utf-8")
            out = out_dir / fname
            # Chrome 은 그림을 다 쓰고도 안 끝나거나, 아무것도 안 그리고 끝날 때가 있다.
            # 파일이 생기고 크기가 멈추면 다 된 것으로 보고 닫는다. 세 번까지 한다.
            for _ in range(3):
                out.unlink(missing_ok=True)
                proc = subprocess.Popen([CHROME, "--headless=new", f"--screenshot={out}", f"--window-size={W},{H}",
                                         "--force-device-scale-factor=1", "--hide-scrollbars", "--disable-gpu",
                                         "--no-first-run", "--disable-extensions", "--disable-background-networking",
                                         "--virtual-time-budget=3000", "--allow-file-access-from-files",
                                         f"--user-data-dir={tmp / 'chrome'}", html.as_uri()],
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                size, deadline = -1, time.time() + 90
                while time.time() < deadline:
                    time.sleep(1)
                    now = out.stat().st_size if out.exists() else -1
                    if now > 0 and now == size:
                        break
                    if proc.poll() is not None and now <= 0:
                        break
                    size = now
                proc.kill(); proc.wait()
                if out.exists() and out.stat().st_size > 0:
                    break
            else:
                raise SystemExit(f"Chrome 이 그리지 못했다: {out}")
            print("rendered", out.relative_to(ROOT))


if __name__ == "__main__":
    main(sys.argv[1:] or list(STORE))
