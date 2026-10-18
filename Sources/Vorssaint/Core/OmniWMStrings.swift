// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct OmniWMStrings {
    let title = "OmniWM"
    let hint: String
    /// One line for the Features page.
    let hubDescription: String
    let size: String
    let sizeHint: String
    let defaultSize: String
    /// Shown while the Dynamic Island, where the strip is drawn, is off.
    let needsIsland: String
    let keywords: String

    /// What a search finds its page by, besides its name.
    var searchKeywords: [String] { [hint, size, sizeHint, keywords] }
}

extension FeatureStrings {
    static func omniWM(_ language: AppLanguage) -> OmniWMStrings {
        switch language {
        case .enUS: return OmniWMStrings(
            hint: "Shows OmniWM’s workspaces in the Dynamic Island. Hold ⌥ to see them and switch between them.",
            hubDescription: "OmniWM’s workspaces and their apps in the Dynamic Island, one click to switch.",
            size: "Size", sizeHint: "Scales the workspace strip, its app icons and the list below it.",
            defaultSize: "Default", needsIsland: "The workspaces are drawn in the Dynamic Island, which is off.",
            keywords: "workspaces tiling window manager omni")
        case .ptBR: return OmniWMStrings(
            hint: "Mostra os espaços de trabalho do OmniWM no Dynamic Island. Segure ⌥ para vê-los e alternar entre eles.",
            hubDescription: "Os espaços do OmniWM e seus apps no Dynamic Island, com um clique para alternar.",
            size: "Tamanho", sizeHint: "Ajusta a faixa de espaços, os ícones dos apps e a lista abaixo dela.",
            defaultSize: "Padrão", needsIsland: "Os espaços aparecem no Dynamic Island, que está desligado.",
            keywords: "espaços de trabalho janelas gerenciador omni")
        case .es: return OmniWMStrings(
            hint: "Muestra los espacios de trabajo de OmniWM en el Dynamic Island. Mantén ⌥ para verlos y cambiar entre ellos.",
            hubDescription: "Los espacios de OmniWM y sus apps en el Dynamic Island, con un clic para cambiar.",
            size: "Tamaño", sizeHint: "Cambia la tira de espacios, los iconos de las apps y la lista de debajo.",
            defaultSize: "Predeterminado", needsIsland: "Los espacios se dibujan en el Dynamic Island, que está desactivado.",
            keywords: "espacios de trabajo ventanas gestor omni")
        case .sk: return OmniWMStrings(
            hint: "Zobrazí pracovné plochy OmniWM v Dynamic Island. Podržte ⌥, aby ste ich videli a prepínali medzi nimi.",
            hubDescription: "Pracovné plochy OmniWM a ich aplikácie v Dynamic Island, prepnutie jedným klikom.",
            size: "Veľkosť", sizeHint: "Mení veľkosť pásu plôch, ikon aplikácií a zoznamu pod ním.",
            defaultSize: "Predvolená", needsIsland: "Pracovné plochy sa kreslia v Dynamic Island, ktorý je vypnutý.",
            keywords: "pracovné plochy okná správca omni")
        case .de: return OmniWMStrings(
            hint: "Zeigt die Arbeitsbereiche von OmniWM im Dynamic Island. Halte ⌥, um sie zu sehen und zwischen ihnen zu wechseln.",
            hubDescription: "Die Arbeitsbereiche von OmniWM und ihre Apps im Dynamic Island, mit einem Klick wechseln.",
            size: "Größe", sizeHint: "Skaliert die Leiste der Arbeitsbereiche, ihre App-Symbole und die Liste darunter.",
            defaultSize: "Standard", needsIsland: "Die Arbeitsbereiche erscheinen im Dynamic Island, das ausgeschaltet ist.",
            keywords: "arbeitsbereiche fenster manager omni")
        case .fr: return OmniWMStrings(
            hint: "Affiche les espaces de travail d’OmniWM dans le Dynamic Island. Maintenez ⌥ pour les voir et passer de l’un à l’autre.",
            hubDescription: "Les espaces d’OmniWM et leurs apps dans le Dynamic Island, un clic pour changer.",
            size: "Taille", sizeHint: "Change la taille de la barre d’espaces, des icônes d’apps et de la liste en dessous.",
            defaultSize: "Par défaut", needsIsland: "Les espaces s’affichent dans le Dynamic Island, qui est désactivé.",
            keywords: "espaces de travail fenêtres gestionnaire omni")
        case .it: return OmniWMStrings(
            hint: "Mostra gli spazi di lavoro di OmniWM nel Dynamic Island. Tieni premuto ⌥ per vederli e passare dall’uno all’altro.",
            hubDescription: "Gli spazi di OmniWM e le loro app nel Dynamic Island, un clic per passare.",
            size: "Dimensione", sizeHint: "Ridimensiona la barra degli spazi, le icone delle app e l’elenco sotto.",
            defaultSize: "Predefinita", needsIsland: "Gli spazi sono disegnati nel Dynamic Island, che è spento.",
            keywords: "spazi di lavoro finestre gestore omni")
        case .ru: return OmniWMStrings(
            hint: "Показывает рабочие пространства OmniWM в Dynamic Island. Удерживайте ⌥, чтобы увидеть их и переключаться.",
            hubDescription: "Пространства OmniWM и их приложения в Dynamic Island, переключение одним щелчком.",
            size: "Размер", sizeHint: "Меняет размер полосы пространств, значков приложений и списка под ней.",
            defaultSize: "По умолчанию", needsIsland: "Пространства рисуются в Dynamic Island, который выключен.",
            keywords: "рабочие пространства окна менеджер omni")
        case .tr: return OmniWMStrings(
            hint: "OmniWM çalışma alanlarını Dynamic Island’da gösterir. Görmek ve aralarında geçmek için ⌥ tuşunu basılı tutun.",
            hubDescription: "OmniWM çalışma alanları ve uygulamaları Dynamic Island’da, tek tıkla geçiş.",
            size: "Boyut", sizeHint: "Çalışma alanı şeridini, uygulama simgelerini ve altındaki listeyi ölçekler.",
            defaultSize: "Varsayılan", needsIsland: "Çalışma alanları kapalı olan Dynamic Island’da çizilir.",
            keywords: "çalışma alanları pencere yöneticisi omni")
        case .ja: return OmniWMStrings(
            hint: "OmniWM のワークスペースを Dynamic Island に表示します。⌥ を押し続けると表示され、切り替えられます。",
            hubDescription: "OmniWM のワークスペースとそのアプリを Dynamic Island に表示し、クリックで切り替えます。",
            size: "サイズ", sizeHint: "ワークスペースのバー、アプリのアイコン、その下のリストの大きさを変えます。",
            defaultSize: "デフォルト", needsIsland: "ワークスペースは Dynamic Island に表示されますが、オフになっています。",
            keywords: "ワークスペース タイル ウインドウ マネージャ omni")
        case .ko: return OmniWMStrings(
            hint: "OmniWM의 작업 공간을 Dynamic Island에 표시합니다. ⌥를 길게 누르면 보이고 전환할 수 있습니다.",
            hubDescription: "OmniWM의 작업 공간과 앱을 Dynamic Island에 표시하고, 클릭 한 번으로 전환합니다.",
            size: "크기", sizeHint: "작업 공간 막대, 앱 아이콘, 그 아래 목록의 크기를 조절합니다.",
            defaultSize: "기본값", needsIsland: "작업 공간은 Dynamic Island에 그려지는데, 지금 꺼져 있습니다.",
            keywords: "작업 공간 윈도우 관리자 omni")
        case .uk: return OmniWMStrings(
            hint: "Показує робочі простори OmniWM у Dynamic Island. Утримуйте ⌥, щоб побачити їх і перемикатися.",
            hubDescription: "Простори OmniWM та їхні застосунки в Dynamic Island, перемикання одним клацанням.",
            size: "Розмір", sizeHint: "Змінює розмір смуги просторів, значків застосунків і списку під нею.",
            defaultSize: "Типово", needsIsland: "Простори малюються в Dynamic Island, який вимкнений.",
            keywords: "робочі простори вікна менеджер omni")
        case .zhHans: return OmniWMStrings(
            hint: "在灵动岛中显示 OmniWM 的工作区。按住 ⌥ 即可查看并在它们之间切换。",
            hubDescription: "在灵动岛中显示 OmniWM 的工作区及其 App，点按即可切换。",
            size: "大小", sizeHint: "调整工作区条、App 图标和下方列表的大小。",
            defaultSize: "默认", needsIsland: "工作区绘制在灵动岛中，而灵动岛已关闭。",
            keywords: "工作区 平铺 窗口 管理器 omni")
        case .zhTW: return OmniWMStrings(
            hint: "在動態島中顯示 OmniWM 的工作區。按住 ⌥ 即可檢視並在它們之間切換。",
            hubDescription: "在動態島中顯示 OmniWM 的工作區及其 App，點一下即可切換。",
            size: "大小", sizeHint: "調整工作區列、App 圖示和下方清單的大小。",
            defaultSize: "預設", needsIsland: "工作區繪製在動態島中，而動態島已關閉。",
            keywords: "工作區 平鋪 視窗 管理器 omni")
        case .zhHK: return OmniWMStrings(
            hint: "在動態島中顯示 OmniWM 的工作區。按住 ⌥ 即可查看並在它們之間切換。",
            hubDescription: "在動態島中顯示 OmniWM 的工作區及其 App，點一下即可切換。",
            size: "大小", sizeHint: "調整工作區列、App 圖示和下方清單的大小。",
            defaultSize: "預設", needsIsland: "工作區繪製在動態島中，而動態島已關閉。",
            keywords: "工作區 平鋪 視窗 管理器 omni")
        }
    }
}
