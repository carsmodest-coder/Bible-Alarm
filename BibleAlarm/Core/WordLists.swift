import Foundation

/// Small, editable word lists used when choosing which words to hide.
enum WordLists {
    /// Lowercases and straightens apostrophes so "LORD", "Lord" and "lord" compare equal.
    static func normalize(_ word: String) -> String {
        word.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
    }

    /// Meaningful words to hide first, most important first.
    static let englishKeywords: [String] = [
        "god", "lord", "jesus", "christ", "yahweh", "love", "peace", "faith", "hope", "strength", "grace", "joy",
        "mercy", "spirit", "heart", "light", "truth", "life", "salvation", "wisdom", "trust", "word",
        "righteousness", "glory", "blessed", "holy", "rest", "prayer", "praise",
    ]

    static let chineseKeywords: [String] = [
        "神", "主", "耶穌", "基督", "耶和華", "愛", "平安", "信心", "盼望", "力量", "恩典", "喜樂", "慈愛", "聖靈",
        "心", "光", "真理", "生命", "救恩", "智慧", "倚靠", "話", "公義", "榮耀", "福", "安息", "禱告", "讚美",
    ]

    /// Common words that are never hidden.
    static let englishStopwords: Set<String> = [
        "the", "and", "of", "to", "a", "an", "in", "that", "for", "is", "unto", "thou", "thy", "thee", "ye", "he",
        "she", "it", "his", "her", "him", "i", "me", "my", "we", "our", "us", "you", "your", "they", "them", "their",
        "be", "are", "was", "were", "am", "been", "not", "but", "with", "as", "at", "by", "on", "or", "so", "if",
        "shall", "will", "hath", "have", "has", "had", "do", "doth", "did", "which", "who", "whom", "this", "these",
        "those", "there", "then", "than", "from", "all", "also", "upon", "into", "when", "what", "let", "may", "no",
        "nor", "o", "yea", "thine", "mine", "shalt", "wilt", "art", "hast", "saith", "said", "say", "because",
        "therefore", "wherefore", "things", "thing", "every", "any", "one", "out", "up", "now", "even", "more", "can",
        "would", "should", "must", "such", "own", "how", "through", "after", "before", "over", "about", "again",
        "yet", "them", "whose", "where", "while", "until", "though", "neither", "either", "each", "both", "some",
        "its", "himself", "itself", "yourselves", "themselves", "don't", "doesn't", "didn't", "won't", "can't",
        "isn't", "aren't", "hasn't", "haven't", "shouldn't", "wouldn't", "couldn't", "wasn't", "weren't",
    ]

    static let chineseStopwords: Set<String> = [
        "的", "了", "是", "在", "和", "與", "他", "你", "我", "這", "那", "就", "也", "都", "不", "有", "為", "而",
        "及", "或", "把", "被", "將", "要", "必", "們", "之", "其", "所", "以", "於", "因", "乃", "又", "並", "但",
        "卻", "使", "叫", "給", "對", "向", "從", "到", "著", "着", "過", "嗎", "呢", "啊", "吧", "你們", "我們",
        "他們", "自己", "因為", "所以", "如此", "這樣", "那些", "這些", "甚麼", "什麼", "一切", "凡", "若", "如",
        "像", "說", "上", "下", "中", "裏", "裡", "人", "來", "去", "得", "能", "可", "當", "並且", "就是", "不是",
        "不要", "不可", "一", "個", "那裏", "這裏", "怎樣", "如同", "直到", "還", "更", "最", "很", "已", "已經",
    ]

    static func isStopword(_ word: String, isChinese: Bool) -> Bool {
        isChinese ? chineseStopwords.contains(word) : englishStopwords.contains(normalize(word))
    }

    /// Position in the keyword list, or nil if the word is not a keyword. Lower means more important.
    static func keywordRank(_ word: String, isChinese: Bool) -> Int? {
        isChinese ? chineseKeywords.firstIndex(of: word) : englishKeywords.firstIndex(of: normalize(word))
    }
}
