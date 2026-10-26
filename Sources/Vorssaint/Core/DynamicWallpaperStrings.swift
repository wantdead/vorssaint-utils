// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct DynamicWallpaperStrings {
    let title: String
    let off: String
    let appearance: String
    let schedule: String
    let day: String
    let night: String
    let chooseImage: String
    let missingImages: String
    let appearanceHint: String
    let scheduleHint: String
    let invalidTimes: String
    let unavailable: String

    static func localized(_ language: AppLanguage) -> Self {
        switch language {
        case .enUS:
            return Self(title: "Dynamic wallpaper", off: "Off", appearance: "System appearance",
                schedule: "Schedule", day: "Day", night: "Night", chooseImage: "Choose image…",
                missingImages: "Choose both images to start switching automatically.",
                appearanceHint: "Follows macOS Light and Dark Mode. Choosing a still stops switching.",
                scheduleHint: "Switches at these local times while Vorssaint is running.",
                invalidTimes: "Day and night must start at different times.",
                unavailable: "An image is unavailable. Choose it again.")
        case .ptBR:
            return Self(title: "Papel de parede dinâmico", off: "Desativado", appearance: "Aparência do sistema",
                schedule: "Horário", day: "Dia", night: "Noite", chooseImage: "Escolher imagem…",
                missingImages: "Escolha as duas imagens para alternar automaticamente.",
                appearanceHint: "Segue os modos Claro e Escuro do macOS. Escolher uma imagem fixa interrompe a alternância.",
                scheduleHint: "Alterna nestes horários locais enquanto o Vorssaint está em execução.",
                invalidTimes: "O dia e a noite devem começar em horários diferentes.",
                unavailable: "Uma imagem está indisponível. Escolha-a novamente.")
        case .tr:
            return Self(title: "Dinamik duvar kâğıdı", off: "Kapalı", appearance: "Sistem görünümü",
                schedule: "Zamanlama", day: "Gündüz", night: "Gece", chooseImage: "Görüntü seç…",
                missingImages: "Otomatik geçiş için her iki görüntüyü de seçin.",
                appearanceHint: "macOS Açık ve Koyu Modunu izler. Sabit bir görüntü seçmek geçişi durdurur.",
                scheduleHint: "Vorssaint çalışırken bu yerel saatlerde geçiş yapar.",
                invalidTimes: "Gündüz ve gece farklı saatlerde başlamalıdır.",
                unavailable: "Bir görüntü kullanılamıyor. Yeniden seçin.")
        case .ru:
            return Self(title: "Динамические обои", off: "Выключено", appearance: "Оформление macOS",
                schedule: "По расписанию", day: "День", night: "Ночь", chooseImage: "Выбрать изображение…",
                missingImages: "Выберите оба изображения для автоматической смены.",
                appearanceHint: "Следует светлой и тёмной теме macOS. Выбор обычных обоев отключает смену.",
                scheduleHint: "Меняет обои в указанное местное время, пока Vorssaint работает.",
                invalidTimes: "День и ночь должны начинаться в разное время.",
                unavailable: "Изображение недоступно. Выберите его заново.")
        case .es:
            return Self(title: "Fondo dinámico", off: "Desactivado", appearance: "Apariencia del sistema",
                schedule: "Horario", day: "Día", night: "Noche", chooseImage: "Elegir imagen…",
                missingImages: "Elige ambas imágenes para cambiar automáticamente.",
                appearanceHint: "Sigue los modos Claro y Oscuro de macOS. Elegir un fondo fijo detiene el cambio.",
                scheduleHint: "Cambia a estas horas locales mientras Vorssaint está abierto.",
                invalidTimes: "El día y la noche deben empezar a horas distintas.",
                unavailable: "Una imagen no está disponible. Vuelve a elegirla.")
        case .sk:
            return Self(title: "Dynamická tapeta", off: "Vypnuté", appearance: "Vzhľad systému",
                schedule: "Rozvrh", day: "Deň", night: "Noc", chooseImage: "Vybrať obrázok…",
                missingImages: "Vyberte oba obrázky na automatické prepínanie.",
                appearanceHint: "Sleduje svetlý a tmavý režim macOS. Výber stálej tapety zastaví prepínanie.",
                scheduleHint: "Prepína v týchto miestnych časoch, keď je Vorssaint spustený.",
                invalidTimes: "Deň a noc sa musia začínať v rôznych časoch.",
                unavailable: "Obrázok nie je dostupný. Vyberte ho znova.")
        case .de:
            return Self(title: "Dynamischer Hintergrund", off: "Aus", appearance: "Systemdarstellung",
                schedule: "Zeitplan", day: "Tag", night: "Nacht", chooseImage: "Bild auswählen…",
                missingImages: "Wähle beide Bilder für den automatischen Wechsel aus.",
                appearanceHint: "Folgt dem hellen und dunklen Modus von macOS. Ein festes Bild beendet den Wechsel.",
                scheduleHint: "Wechselt zu diesen Ortszeiten, solange Vorssaint läuft.",
                invalidTimes: "Tag und Nacht müssen zu unterschiedlichen Zeiten beginnen.",
                unavailable: "Ein Bild ist nicht verfügbar. Wähle es erneut aus.")
        case .fr:
            return Self(title: "Fond d’écran dynamique", off: "Désactivé", appearance: "Apparence du système",
                schedule: "Horaires", day: "Jour", night: "Nuit", chooseImage: "Choisir une image…",
                missingImages: "Choisissez les deux images pour activer le changement automatique.",
                appearanceHint: "Suit les modes Clair et Sombre de macOS. Choisir un fond fixe arrête le changement.",
                scheduleHint: "Change à ces heures locales tant que Vorssaint est ouvert.",
                invalidTimes: "Le jour et la nuit doivent commencer à des heures différentes.",
                unavailable: "Une image est indisponible. Choisissez-la à nouveau.")
        case .it:
            return Self(title: "Sfondo dinamico", off: "Disattivato", appearance: "Aspetto del sistema",
                schedule: "Orario", day: "Giorno", night: "Notte", chooseImage: "Scegli immagine…",
                missingImages: "Scegli entrambe le immagini per il cambio automatico.",
                appearanceHint: "Segue le modalità Chiara e Scura di macOS. Scegliere uno sfondo fisso interrompe il cambio.",
                scheduleHint: "Cambia a queste ore locali mentre Vorssaint è in esecuzione.",
                invalidTimes: "Il giorno e la notte devono iniziare a ore diverse.",
                unavailable: "Un’immagine non è disponibile. Sceglila di nuovo.")
        case .ja:
            return Self(title: "ダイナミック壁紙", off: "オフ", appearance: "システムの外観",
                schedule: "スケジュール", day: "昼", night: "夜", chooseImage: "画像を選択…",
                missingImages: "自動切り替えを始めるには両方の画像を選択してください。",
                appearanceHint: "macOSのライト・ダークモードに連動します。静止画を選ぶと切り替えを停止します。",
                scheduleHint: "Vorssaintの実行中、指定した現地時刻に切り替わります。",
                invalidTimes: "昼と夜の開始時刻を異なる時刻にしてください。",
                unavailable: "画像を使用できません。もう一度選択してください。")
        case .ko:
            return Self(title: "다이내믹 배경화면", off: "끔", appearance: "시스템 화면 모드",
                schedule: "시간 설정", day: "낮", night: "밤", chooseImage: "이미지 선택…",
                missingImages: "자동 전환을 시작하려면 두 이미지를 모두 선택하세요.",
                appearanceHint: "macOS 라이트 및 다크 모드를 따릅니다. 고정 이미지를 선택하면 전환이 중지됩니다.",
                scheduleHint: "Vorssaint가 실행 중일 때 지정한 현지 시각에 전환합니다.",
                invalidTimes: "낮과 밤의 시작 시각은 달라야 합니다.",
                unavailable: "이미지를 사용할 수 없습니다. 다시 선택하세요.")
        case .uk:
            return Self(title: "Динамічні шпалери", off: "Вимкнено", appearance: "Вигляд macOS",
                schedule: "За розкладом", day: "День", night: "Ніч", chooseImage: "Вибрати зображення…",
                missingImages: "Виберіть обидва зображення для автоматичної зміни.",
                appearanceHint: "Слідує світлій і темній темі macOS. Вибір звичайних шпалер вимикає зміну.",
                scheduleHint: "Змінює шпалери у вказаний місцевий час, доки Vorssaint працює.",
                invalidTimes: "День і ніч мають починатися в різний час.",
                unavailable: "Зображення недоступне. Виберіть його знову.")
        case .zhHans:
            return Self(title: "动态壁纸", off: "关闭", appearance: "系统外观",
                schedule: "定时", day: "白天", night: "夜晚", chooseImage: "选择图像…",
                missingImages: "请选择两张图像以开始自动切换。",
                appearanceHint: "跟随 macOS 浅色和深色模式。选择静态壁纸会停止切换。",
                scheduleHint: "在 Vorssaint 运行期间，按指定的本地时间切换。",
                invalidTimes: "白天和夜晚的开始时间必须不同。",
                unavailable: "图像不可用。请重新选择。")
        case .zhTW:
            return Self(title: "動態背景圖片", off: "關閉", appearance: "系統外觀",
                schedule: "排程", day: "白天", night: "夜晚", chooseImage: "選擇影像…",
                missingImages: "請選擇兩張影像以開始自動切換。",
                appearanceHint: "跟隨 macOS 淺色與深色模式。選擇靜態背景會停止切換。",
                scheduleHint: "Vorssaint 執行期間，會在指定的當地時間切換。",
                invalidTimes: "白天與夜晚的開始時間必須不同。",
                unavailable: "影像無法使用。請重新選擇。")
        case .zhHK:
            return Self(title: "動態背景圖片", off: "關閉", appearance: "系統外觀",
                schedule: "時間表", day: "日間", night: "夜間", chooseImage: "選擇影像…",
                missingImages: "請選擇兩張影像以開始自動切換。",
                appearanceHint: "跟隨 macOS 淺色及深色模式。選擇靜態背景會停止切換。",
                scheduleHint: "Vorssaint 執行期間，會在指定的本地時間切換。",
                invalidTimes: "日間及夜間的開始時間必須不同。",
                unavailable: "影像無法使用。請重新選擇。")
        }
    }
}
