// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Localized strings for translate, which turns Russian into English and
/// English into Russian on the Mac.
struct TranslateFeatureStrings {
    let pageTitle: String
    let hubDescription: String
    let placeholder: String
    let swapHint: String
    let copyHint: String
    let downloadNeeded: String
    let failed: String
    let unavailable: String
}

extension FeatureStrings {
    static func translate(_ language: AppLanguage) -> TranslateFeatureStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension TranslateFeatureStrings {
    static let enUS = TranslateFeatureStrings(
        pageTitle: "Translate",
        hubDescription: "Russian and English translation on your Mac",
        placeholder: "Paste or type text to translate",
        swapHint: "Swap direction",
        copyHint: "Copy translation",
        downloadNeeded: "A translation language is not installed. Add it in System Settings, then try again.",
        failed: "The text could not be translated",
        unavailable: "Translation needs macOS 15 or later")

    static let ptBR = TranslateFeatureStrings(
        pageTitle: "Traduzir",
        hubDescription: "Tradução entre russo e inglês no seu Mac",
        placeholder: "Cole ou digite o texto para traduzir",
        swapHint: "Inverter direção",
        copyHint: "Copiar tradução",
        downloadNeeded: "Um idioma de tradução não está instalado. Adicione-o em Ajustes do Sistema e tente de novo.",
        failed: "Não foi possível traduzir o texto",
        unavailable: "A tradução exige o macOS 15 ou mais recente")

    static let tr = TranslateFeatureStrings(
        pageTitle: "Çevir",
        hubDescription: "Mac’inizde Rusça ve İngilizce çeviri",
        placeholder: "Çevrilecek metni yapıştırın veya yazın",
        swapHint: "Yönü değiştir",
        copyHint: "Çeviriyi kopyala",
        downloadNeeded: "Bir çeviri dili yüklü değil. Sistem Ayarları’ndan ekleyip tekrar deneyin.",
        failed: "Metin çevrilemedi",
        unavailable: "Çeviri için macOS 15 veya üstü gerekir")

    static let ru = TranslateFeatureStrings(
        pageTitle: "Перевод",
        hubDescription: "Перевод между русским и английским на вашем Mac",
        placeholder: "Вставьте или введите текст для перевода",
        swapHint: "Сменить направление",
        copyHint: "Скопировать перевод",
        downloadNeeded: "Язык для перевода не установлен. Добавьте его в Системных настройках и повторите попытку.",
        failed: "Не удалось перевести текст",
        unavailable: "Для перевода нужна macOS 15 или новее")

    static let es = TranslateFeatureStrings(
        pageTitle: "Traducir",
        hubDescription: "Traducción entre ruso e inglés en tu Mac",
        placeholder: "Pega o escribe el texto que quieres traducir",
        swapHint: "Invertir dirección",
        copyHint: "Copiar traducción",
        downloadNeeded: "Falta un idioma de traducción. Añádelo en Ajustes del Sistema y vuelve a intentarlo.",
        failed: "No se pudo traducir el texto",
        unavailable: "La traducción requiere macOS 15 o posterior")

    static let sk = TranslateFeatureStrings(
        pageTitle: "Preklad",
        hubDescription: "Preklad medzi ruštinou a angličtinou na vašom Macu",
        placeholder: "Vložte alebo napíšte text na preklad",
        swapHint: "Prehodiť smer",
        copyHint: "Kopírovať preklad",
        downloadNeeded: "Jazyk prekladu nie je nainštalovaný. Pridajte ho v Systémových nastaveniach a skúste to znova.",
        failed: "Text sa nepodarilo preložiť",
        unavailable: "Preklad vyžaduje macOS 15 alebo novší")

    static let de = TranslateFeatureStrings(
        pageTitle: "Übersetzen",
        hubDescription: "Übersetzung zwischen Russisch und Englisch auf deinem Mac",
        placeholder: "Text zum Übersetzen einfügen oder eingeben",
        swapHint: "Richtung tauschen",
        copyHint: "Übersetzung kopieren",
        downloadNeeded: "Eine Übersetzungssprache ist nicht installiert. Füge sie in den Systemeinstellungen hinzu und versuche es erneut.",
        failed: "Der Text konnte nicht übersetzt werden",
        unavailable: "Für die Übersetzung ist macOS 15 oder neuer nötig")

    static let fr = TranslateFeatureStrings(
        pageTitle: "Traduire",
        hubDescription: "Traduction entre le russe et l’anglais sur votre Mac",
        placeholder: "Collez ou saisissez le texte à traduire",
        swapHint: "Inverser le sens",
        copyHint: "Copier la traduction",
        downloadNeeded: "Une langue de traduction n’est pas installée. Ajoutez-la dans Réglages Système, puis réessayez.",
        failed: "Le texte n’a pas pu être traduit",
        unavailable: "La traduction nécessite macOS 15 ou une version ultérieure")

    static let it = TranslateFeatureStrings(
        pageTitle: "Traduci",
        hubDescription: "Traduzione tra russo e inglese sul tuo Mac",
        placeholder: "Incolla o scrivi il testo da tradurre",
        swapHint: "Inverti direzione",
        copyHint: "Copia traduzione",
        downloadNeeded: "Una lingua di traduzione non è installata. Aggiungila in Impostazioni di Sistema e riprova.",
        failed: "Impossibile tradurre il testo",
        unavailable: "La traduzione richiede macOS 15 o successivo")

    static let ja = TranslateFeatureStrings(
        pageTitle: "翻訳",
        hubDescription: "Mac上でロシア語と英語を翻訳します",
        placeholder: "翻訳するテキストを貼り付けるか入力",
        swapHint: "方向を入れ替える",
        copyHint: "翻訳をコピー",
        downloadNeeded: "翻訳用の言語がインストールされていません。システム設定で追加してから、もう一度お試しください。",
        failed: "テキストを翻訳できませんでした",
        unavailable: "翻訳にはmacOS 15以降が必要です")

    static let ko = TranslateFeatureStrings(
        pageTitle: "번역",
        hubDescription: "Mac에서 러시아어와 영어를 번역합니다",
        placeholder: "번역할 텍스트를 붙여넣거나 입력하세요",
        swapHint: "방향 바꾸기",
        copyHint: "번역 복사",
        downloadNeeded: "번역 언어가 설치되어 있지 않습니다. 시스템 설정에서 추가한 다음 다시 시도하세요.",
        failed: "텍스트를 번역할 수 없습니다",
        unavailable: "번역에는 macOS 15 이상이 필요합니다")

    static let zhHans = TranslateFeatureStrings(
        pageTitle: "翻译",
        hubDescription: "在 Mac 上进行俄语和英语互译",
        placeholder: "粘贴或输入要翻译的文本",
        swapHint: "切换方向",
        copyHint: "拷贝译文",
        downloadNeeded: "尚未安装翻译语言。请在“系统设置”中添加后重试。",
        failed: "无法翻译该文本",
        unavailable: "翻译需要 macOS 15 或更高版本")

    static let zhTW = TranslateFeatureStrings(
        pageTitle: "翻譯",
        hubDescription: "在 Mac 上進行俄文和英文互譯",
        placeholder: "貼上或輸入要翻譯的文字",
        swapHint: "切換方向",
        copyHint: "拷貝譯文",
        downloadNeeded: "尚未安裝翻譯語言。請在「系統設定」中加入後再試一次。",
        failed: "無法翻譯該文字",
        unavailable: "翻譯需要 macOS 15 或以上版本")

    static let zhHK = TranslateFeatureStrings(
        pageTitle: "翻譯",
        hubDescription: "喺 Mac 上進行俄文同英文互譯",
        placeholder: "貼上或輸入要翻譯嘅文字",
        swapHint: "切換方向",
        copyHint: "拷貝譯文",
        downloadNeeded: "仲未安裝翻譯語言。請喺「系統設定」入面加入，然後再試一次。",
        failed: "無法翻譯呢段文字",
        unavailable: "翻譯需要 macOS 15 或以上版本")

    static let uk = TranslateFeatureStrings(
        pageTitle: "Переклад",
        hubDescription: "Переклад між російською та англійською на вашому Mac",
        placeholder: "Вставте або введіть текст для перекладу",
        swapHint: "Змінити напрямок",
        copyHint: "Скопіювати переклад",
        downloadNeeded: "Мову для перекладу не встановлено. Додайте її в Системних параметрах і повторіть спробу.",
        failed: "Не вдалося перекласти текст",
        unavailable: "Для перекладу потрібна macOS 15 або новіша")
}
