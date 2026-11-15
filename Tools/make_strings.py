#!/usr/bin/env python3
"""Builds the String Catalogs (English + Traditional Chinese) from the table below.

There is no Mac to edit .xcstrings files in Xcode, so the translations live here.
After changing any text in the app, add or edit its line below and run:

    python3 Tools/make_strings.py

The script also scans the Swift code and lists any text that has no translation yet.
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# English text exactly as it appears in the code  ->  Traditional Chinese.
# Values inserted into a sentence are written %lld (a number) or %@ (text).
STRINGS = {
    # Tabs and titles
    "Alarms": "鬧鐘",
    "Journey": "歷程",
    "Settings": "設定",
    "Bible Alarm": "Bible Alarm",
    "Alarm": "鬧鐘",
    # Home
    "Start today with God's word": "用神的話語開始今天",
    "Today's verse is done": "今天的經文已完成",
    "Read today's verse": "讀今天的經文",
    "Read it again": "再讀一次",
    "Streak": "連續天數",
    "No alarms yet": "還沒有鬧鐘",
    "Add an alarm to start each day with a verse.": "新增鬧鐘，每天以一節經文開始。",
    "Add alarm": "新增鬧鐘",
    "Alarms are turned off": "鬧鐘權限已關閉",
    "Bible Alarm needs permission to ring. Allow alarms in the Settings app.": "Bible Alarm 需要權限才能響鈴。請在「設定」中允許鬧鐘。",
    "Open Settings": "打開設定",
    "OK": "好",
    # Alarm editor
    "New alarm": "新增鬧鐘",
    "Edit alarm": "編輯鬧鐘",
    "Time": "時間",
    "Repeat": "重複",
    "Label": "標籤",
    "Sound": "鈴聲",
    "Difficulty": "難度",
    "Easy (1 word)": "簡單（1 個詞）",
    "Normal (2 words)": "一般（2 個詞）",
    "Ring again every": "再次響鈴間隔",
    "%lld minutes": "%lld 分鐘",
    "If you stop the alarm without finishing the verse, it rings again until you do.": "如果沒有完成經文就停止鬧鐘，鬧鐘會再次響起，直到你完成為止。",
    "Delete alarm": "刪除鬧鐘",
    "Cancel": "取消",
    "Save": "儲存",
    "Once": "一次",
    "Every day": "每天",
    "Weekdays": "平日",
    "Weekends": "週末",
    # Alarm messages
    "Time to read God's word": "該讀神的話語了",
    "Read today's verse to stop the alarm": "讀完今天的經文才能停止鬧鐘",
    "Stop": "停止",
    "Read verse": "讀經文",
    "Stop alarm": "停止鬧鐘",
    "Alarm ID": "鬧鐘編號",
    "Entry ID": "項目編號",
    "Alarms are turned off for Bible Alarm. Allow them in the Settings app.": "Bible Alarm 的鬧鐘權限已關閉。請在「設定」中允許。",
    "iOS will not allow any more alarms. Delete one and try again.": "iOS 不允許再新增鬧鐘。請刪除一個後再試。",
    "The alarm could not be set. Please try again.": "無法設定鬧鐘，請再試一次。",
    # Sounds
    "Built-in": "內建",
    "Your sounds": "你的鈴聲",
    "Dawn": "黎明",
    "Chimes": "風鈴",
    "Harp": "豎琴",
    "Still Waters": "安歇的水邊",
    "iPhone alarm sound": "iPhone 鬧鐘鈴聲",
    "Add your own sound": "加入自己的鈴聲",
    "Record your voice": "錄下你的聲音",
    "Pick an MP3, M4A, WAV or AAC file from the Files app. Your sounds stay on this iPhone and are never uploaded.": "從「檔案」選擇 MP3、M4A、WAV 或 AAC 檔案。你的鈴聲只會留在這部 iPhone，絕不會上傳。",
    "This file can't be used": "無法使用這個檔案",
    "The file could not be read. Songs from Apple Music or Spotify are protected and can't be imported.": "無法讀取檔案。Apple Music 或 Spotify 的歌曲受到保護，無法匯入。",
    "My recording": "我的錄音",
    "My sound": "我的鈴聲",
    "Trim sound": "剪輯鈴聲",
    "Name": "名稱",
    "Start point": "開始位置",
    "Starts at %@ · plays for %lld seconds": "從 %@ 開始 · 播放 %lld 秒",
    "Preview": "試聽",
    "Advanced editing": "進階編輯",
    "Clip length: %lld seconds": "片段長度：%lld 秒",
    "Fade in gently": "漸強淡入",
    "Waveform, clip length and fade-in": "波形、片段長度與淡入",
    "The sound could not be saved": "無法儲存鈴聲",
    "Record up to 30 seconds": "最多可錄 30 秒",
    "Allow the microphone in the Settings app to record.": "請在「設定」中允許使用麥克風才能錄音。",
    "Stop and use": "停止並使用",
    "Start recording": "開始錄音",
    # Verse challenge
    "Close": "關閉",
    "Tap the missing word": "點選缺少的詞",
    "Type the missing word": "輸入缺少的詞",
    "Check": "檢查",
    "Listening… read the verse aloud": "聆聽中…請朗讀經文",
    "Read the verse aloud": "請朗讀經文",
    "Start reading": "開始朗讀",
    "Tap the words instead": "改用點選作答",
    "Allow the microphone and speech recognition in the Settings app to read aloud.": "請在「設定」中允許麥克風與語音辨識，才能朗讀作答。",
    "Speech recognition is not available right now.": "目前無法使用語音辨識。",
    # Success
    "Amen": "阿們",
    "What stands out to you today?": "今天哪一句話觸動了你？",
    "Write a thought (optional)": "寫下感想（可不填）",
    "Favorite": "收藏",
    "Saved": "已收藏",
    "Share": "分享",
    "Read the whole chapter": "閱讀整章",
    "Done": "完成",
    # Journey
    "Day streak": "連續天數",
    "Best streak": "最佳紀錄",
    "Verses read": "已讀經文",
    "Memorize mode": "背經模式",
    "Quiz yourself on verses you have already read.": "用讀過的經文來測驗自己。",
    "Show": "顯示",
    "All": "全部",
    "Favorites": "收藏",
    "No favorites yet. Tap the heart on a verse to keep it here.": "還沒有收藏。在經文上點愛心，就會保存在這裡。",
    "Verses you complete will appear here.": "完成的經文會顯示在這裡。",
    "History": "紀錄",
    "Reflection": "感想",
    "Verse %lld of %lld": "第 %lld 題，共 %lld 題",
    "Well done": "做得好",
    "Verses reviewed: %lld": "已複習經文：%lld",
    # Settings
    "Reading": "讀經",
    "Bible version": "聖經譯本",
    "App language": "App 語言",
    "Change in Settings": "在「設定」中更改",
    "Difficulty here is used when you read the verse without an alarm. Each alarm has its own setting.": "這裡的難度用於沒有鬧鐘時讀經文。每個鬧鐘有自己的設定。",
    "Premium": "進階版",
    "Answer style": "作答方式",
    "Tap the word": "點選",
    "Type the word": "輸入",
    "Read aloud": "朗讀",
    "Verses from": "經文來源",
    "Strict mode": "嚴格模式",
    "Themed sets and reading plans": "主題經文與讀經計畫",
    "Premium is active": "進階版已啟用",
    "See Premium": "了解進階版",
    "Tip jar": "奉獻支持",
    "Restore Purchases": "回復購買項目",
    "No ads, ever. No tracking.": "永遠沒有廣告，也不追蹤。",
    "Permission": "權限",
    "Allowed": "已允許",
    "Turned off": "已關閉",
    "Not asked yet": "尚未詢問",
    "Allow alarms": "允許鬧鐘",
    "Test build": "測試版",
    "Unlock Premium for testing": "測試用：解鎖進階版",
    "Only in test builds. This switch is removed from the App Store version.": "只在測試版出現。App Store 版本不會有這個開關。",
    "Credits": "致謝",
    "Version": "版本",
    "All verses": "所有經文",
    "Themed sets": "主題經文",
    "Reading plans": "讀經計畫",
    "A plan gives you one key verse each morning, in order, with a link to read the whole chapter.": "讀經計畫每天早上依序給你一節重點經文，並可閱讀整章。",
    "Day %lld of %lld": "第 %lld 天，共 %lld 天",
    "Morning": "早晨",
    "Peace": "平安",
    "Strength": "力量",
    "Hope": "盼望",
    "Love": "愛",
    "Faith": "信心",
    "Joy": "喜樂",
    "Comfort": "安慰",
    "Courage": "勇氣",
    "Guidance": "引導",
    "Grace": "恩典",
    "Prayer": "禱告",
    "Gratitude": "感恩",
    "Wisdom": "智慧",
    "Psalms": "詩篇",
    "Proverbs in 31 days": "31 天讀箴言",
    "Psalms in 30 days": "30 天讀詩篇",
    "Gospel of John in 21 days": "21 天讀約翰福音",
    # Credits
    "Bible text": "聖經經文",
    "Text files from the open-bibles project (github.com/seven1m/open-bibles).": "經文檔案來自 open-bibles 專案（github.com/seven1m/open-bibles）。",
    "Sounds": "鈴聲",
    "The built-in alarm tones were created for Bible Alarm. Sounds you add stay on your iPhone and are never uploaded.": "內建鈴聲是為 Bible Alarm 製作的。你加入的鈴聲只會留在你的 iPhone，絕不會上傳。",
    "Privacy": "隱私",
    "Bible Alarm has no ads and no tracking, and it collects no data.": "Bible Alarm 沒有廣告、不追蹤，也不收集任何資料。",
    # Paywall and tips
    "Bible Alarm Premium": "Bible Alarm 進階版",
    "Strict mode: type the word or read the verse aloud": "嚴格模式：輸入缺少的詞，或朗讀整節經文",
    "Memorize mode: quizzes on verses you have read": "背經模式：用讀過的經文測驗",
    "Themed verse sets and reading plans": "主題經文與讀經計畫",
    "Waveform trim, fade-in and voice recording for alarm sounds": "鈴聲波形剪輯、淡入與錄音",
    "Loading prices…": "正在載入價格…",
    "Purchases are not available in this build yet.": "這個版本尚未開放購買。",
    "Bible translations stay free. Premium pays for extra features and supports this ministry. Subscriptions renew automatically until cancelled in your App Store account settings.": "聖經譯本永遠免費。進階版提供額外功能，並支持這項事工。訂閱會自動續訂，直到你在 App Store 帳號設定中取消。",
    "%@ once": "%@（一次付清）",
    "%@ per year": "每年 %@",
    "%@ per month": "每月 %@",
    "7-day free trial, then %@": "免費試用 7 天，之後%@",
    "Thank you! Your purchase is complete.": "謝謝你！購買已完成。",
    "The purchase could not be verified.": "無法驗證這筆購買。",
    "Your purchase is waiting for approval.": "你的購買正在等待核准。",
    "The purchase did not go through. Please try again.": "購買未完成，請再試一次。",
    "Your purchases have been restored.": "已回復你的購買項目。",
    "No purchases were found to restore.": "找不到可回復的購買項目。",
    "Support this ministry": "支持這項事工",
    "Bible Alarm has no ads and never will. If it helps you, a tip helps keep it going.": "Bible Alarm 沒有廣告，以後也不會有。如果它幫助了你，你的奉獻能讓它繼續下去。",
    # Onboarding
    "Wake up to God's word": "在神的話語中醒來",
    "When your alarm rings, a Bible verse is waiting. Fill in the missing word to start your day.": "鬧鐘響起時，一節經文正等著你。填上缺少的詞，開始新的一天。",
    "An alarm that waits for you": "等你讀完的鬧鐘",
    "If you stop the alarm without reading, it rings again every few minutes until you finish the verse. Bible Alarm needs your permission to ring, even in Silent mode.": "如果沒讀經文就停止鬧鐘，它會每隔幾分鐘再響，直到你完成經文。Bible Alarm 需要你的允許才能響鈴，即使在靜音模式也一樣。",
    "Choose your Bible": "選擇聖經譯本",
    "You can change this later in Settings. The app follows your iPhone's language (English or 繁體中文).": "之後可以在設定中更改。App 會跟隨 iPhone 的語言（English 或繁體中文）。",
    "Continue": "繼續",
    "Get started": "開始使用",
}

# Permission explanations shown by iOS (Info.plist).
INFO_PLIST = {
    "NSAlarmKitUsageDescription": (
        "Bible Alarm rings the alarms you set, even in Silent mode or a Focus.",
        "Bible Alarm 會在你設定的時間響鈴，即使在靜音模式或專注模式也一樣。"),
    "NSMicrophoneUsageDescription": (
        "The microphone is used when you record your own alarm sound or read a verse aloud.",
        "錄製自己的鈴聲或朗讀經文時會使用麥克風。"),
    "NSSpeechRecognitionUsageDescription": (
        "Speech recognition checks the verse you read aloud.",
        "語音辨識用來核對你朗讀的經文。"),
}

# Text in the code that is deliberately not translated.
IGNORE = {" ", "Mon Wed Fri", "Could not open the app's database: %?", "Support this ministry.", "＿"}


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def write(path, strings):
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"sourceLanguage": "en", "strings": strings, "version": "1.0"}, f,
                  ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")


def scan():
    found = set()
    for folder in ("App", "Features", "Services", "Models"):
        for base, _, files in os.walk(os.path.join(ROOT, "BibleAlarm", folder)):
            for name in files:
                if name.endswith(".swift"):
                    text = open(os.path.join(base, name), encoding="utf-8").read()
                    text = re.sub(r"//.*", "", text)
                    for literal in re.findall(r'"((?:[^"\\\n]|\\.)*)"', text):
                        found.add(literal)
    missing = []
    known = {re.sub(r"%lld|%@", "%?", key) for key in STRINGS} | IGNORE
    for literal in sorted(found):
        # Skip identifiers, keys and symbol names: only sentences and capitalised words are user-facing.
        if not re.search(r"[A-Z ]", literal) or re.fullmatch(r"[A-Za-z0-9._:<>\-]*", literal) and not literal[:1].isupper():
            continue
        if re.fullmatch(r"[A-Z0-9]{3}( [0-9:]+)?|[a-z]{2}-[A-Z]{2}", literal):
            continue
        normalised = re.sub(r"\\\((?:[^()]|\([^()]*\)|\((?:[^()]|\([^()]*\))*\))*\)", "%?", literal)
        if normalised not in known:
            missing.append(literal)
    return missing


if __name__ == "__main__":
    resources = os.path.join(ROOT, "BibleAlarm", "Resources")
    write(os.path.join(resources, "Localizable.xcstrings"),
          {key: {"localizations": {"zh-Hant": unit(value)}} for key, value in STRINGS.items()})
    write(os.path.join(resources, "InfoPlist.xcstrings"),
          {key: {"localizations": {"en": unit(en), "zh-Hant": unit(zh)}} for key, (en, zh) in INFO_PLIST.items()})
    print("Wrote %d strings." % len(STRINGS))
    missing = scan()
    if missing:
        print("No translation yet for:")
        for literal in missing:
            print("   ", literal)
