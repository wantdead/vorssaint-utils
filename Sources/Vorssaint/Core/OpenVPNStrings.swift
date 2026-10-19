// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// VPN panel section strings.
struct OpenVPNFeatureStrings {
    let pageTitle: String
    let hubDescription: String
    let panelDescription: String
    let statusConnected: String
    let statusConnecting: String
    let statusDisconnected: String
    let connect: String
    let disconnect: String
    let openApp: String
    let pinHint: String
    let profile: String
    let appMissing: String
    let cannotControl: String
    let noProfiles: String
}

extension FeatureStrings {
    static func openVPN(_ language: AppLanguage) -> OpenVPNFeatureStrings {
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
        case .uk: return .uk
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        }
    }
}

extension OpenVPNFeatureStrings {
    static let enUS = OpenVPNFeatureStrings(
        pageTitle: "VPN",
        hubDescription: "See OpenVPN Connect’s status and connect or disconnect from the panel",
        panelDescription: "See OpenVPN Connect’s status and connect or disconnect from the panel.",
        statusConnected: "Connected",
        statusConnecting: "Connecting…",
        statusDisconnected: "Disconnected",
        connect: "Connect",
        disconnect: "Disconnect",
        openApp: "Open OpenVPN Connect",
        pinHint: "Enter the PIN in OpenVPN Connect",
        profile: "Profile",
        appMissing: "OpenVPN Connect is not installed",
        cannotControl: "Can’t control OpenVPN Connect",
        noProfiles: "No profiles in OpenVPN Connect")

    static let ptBR = OpenVPNFeatureStrings(
        pageTitle: "VPN",
        hubDescription: "Veja o estado do OpenVPN Connect e conecte ou desconecte pelo painel",
        panelDescription: "Veja o estado do OpenVPN Connect e conecte ou desconecte pelo painel.",
        statusConnected: "Conectado",
        statusConnecting: "Conectando…",
        statusDisconnected: "Desconectado",
        connect: "Conectar",
        disconnect: "Desconectar",
        openApp: "Abrir o OpenVPN Connect",
        pinHint: "Digite o PIN no OpenVPN Connect",
        profile: "Perfil",
        appMissing: "O OpenVPN Connect não está instalado",
        cannotControl: "Não foi possível controlar o OpenVPN Connect",
        noProfiles: "Nenhum perfil no OpenVPN Connect")

    static let tr = OpenVPNFeatureStrings(
        pageTitle: "VPN",
        hubDescription: "OpenVPN Connect durumunu görün, panelden bağlanın veya bağlantıyı kesin",
        panelDescription: "OpenVPN Connect durumunu görün, panelden bağlanın veya bağlantıyı kesin.",
        statusConnected: "Bağlı",
        statusConnecting: "Bağlanıyor…",
        statusDisconnected: "Bağlı değil",
        connect: "Bağlan",
        disconnect: "Bağlantıyı kes",
        openApp: "OpenVPN Connect’i aç",
        pinHint: "PIN’i OpenVPN Connect’te girin",
        profile: "Profil",
        appMissing: "OpenVPN Connect yüklü değil",
        cannotControl: "OpenVPN Connect kontrol edilemiyor",
        noProfiles: "OpenVPN Connect’te profil yok")

    static let ru = OpenVPNFeatureStrings(
        pageTitle: "VPN",
        hubDescription: "Статус OpenVPN Connect, подключение и отключение прямо из панели",
        panelDescription: "Статус OpenVPN Connect, подключение и отключение прямо из панели.",
        statusConnected: "Подключено",
        statusConnecting: "Подключение…",
        statusDisconnected: "Отключено",
        connect: "Подключить",
        disconnect: "Отключить",
        openApp: "Открыть OpenVPN Connect",
        pinHint: "Введите PIN в OpenVPN Connect",
        profile: "Профиль",
        appMissing: "OpenVPN Connect не установлен",
        cannotControl: "Не удаётся управлять OpenVPN Connect",
        noProfiles: "В OpenVPN Connect нет профилей")

    static let es = OpenVPNFeatureStrings(
        pageTitle: "VPN",
        hubDescription: "Consulta el estado de OpenVPN Connect y conecta o desconecta desde el panel",
        panelDescription: "Consulta el estado de OpenVPN Connect y conecta o desconecta desde el panel.",
        statusConnected: "Conectado",
        statusConnecting: "Conectando…",
        statusDisconnected: "Desconectado",
        connect: "Conectar",
        disconnect: "Desconectar",
        openApp: "Abrir OpenVPN Connect",
        pinHint: "Introduce el PIN en OpenVPN Connect",
        profile: "Perfil",
        appMissing: "OpenVPN Connect no está instalado",
        cannotControl: "No se puede controlar OpenVPN Connect",
        noProfiles: "No hay perfiles en OpenVPN Connect")

    static let sk = OpenVPNFeatureStrings(
        pageTitle: "VPN",
        hubDescription: "Zobrazte stav OpenVPN Connect a pripájajte alebo odpájajte z panela",
        panelDescription: "Zobrazte stav OpenVPN Connect a pripájajte alebo odpájajte z panela.",
        statusConnected: "Pripojené",
        statusConnecting: "Pripája sa…",
        statusDisconnected: "Odpojené",
        connect: "Pripojiť",
        disconnect: "Odpojiť",
        openApp: "Otvoriť OpenVPN Connect",
        pinHint: "Zadajte PIN v OpenVPN Connect",
        profile: "Profil",
        appMissing: "OpenVPN Connect nie je nainštalovaný",
        cannotControl: "OpenVPN Connect sa nedá ovládať",
        noProfiles: "V OpenVPN Connect nie sú žiadne profily")

    static let de = OpenVPNFeatureStrings(
        pageTitle: "VPN",
        hubDescription: "Status von OpenVPN Connect sehen und im Panel verbinden oder trennen",
        panelDescription: "Status von OpenVPN Connect sehen und im Panel verbinden oder trennen.",
        statusConnected: "Verbunden",
        statusConnecting: "Verbinde …",
        statusDisconnected: "Getrennt",
        connect: "Verbinden",
        disconnect: "Trennen",
        openApp: "OpenVPN Connect öffnen",
        pinHint: "PIN in OpenVPN Connect eingeben",
        profile: "Profil",
        appMissing: "OpenVPN Connect ist nicht installiert",
        cannotControl: "OpenVPN Connect lässt sich nicht steuern",
        noProfiles: "Keine Profile in OpenVPN Connect")

    static let fr = OpenVPNFeatureStrings(
        pageTitle: "VPN",
        hubDescription: "Voyez l’état d’OpenVPN Connect et connectez-vous ou déconnectez-vous depuis le panneau",
        panelDescription: "Voyez l’état d’OpenVPN Connect et connectez-vous ou déconnectez-vous depuis le panneau.",
        statusConnected: "Connecté",
        statusConnecting: "Connexion…",
        statusDisconnected: "Déconnecté",
        connect: "Se connecter",
        disconnect: "Se déconnecter",
        openApp: "Ouvrir OpenVPN Connect",
        pinHint: "Saisissez le code PIN dans OpenVPN Connect",
        profile: "Profil",
        appMissing: "OpenVPN Connect n’est pas installé",
        cannotControl: "Impossible de contrôler OpenVPN Connect",
        noProfiles: "Aucun profil dans OpenVPN Connect")

    static let it = OpenVPNFeatureStrings(
        pageTitle: "VPN",
        hubDescription: "Vedi lo stato di OpenVPN Connect e connettiti o disconnettiti dal pannello",
        panelDescription: "Vedi lo stato di OpenVPN Connect e connettiti o disconnettiti dal pannello.",
        statusConnected: "Connesso",
        statusConnecting: "Connessione…",
        statusDisconnected: "Disconnesso",
        connect: "Connetti",
        disconnect: "Disconnetti",
        openApp: "Apri OpenVPN Connect",
        pinHint: "Inserisci il PIN in OpenVPN Connect",
        profile: "Profilo",
        appMissing: "OpenVPN Connect non è installato",
        cannotControl: "Impossibile controllare OpenVPN Connect",
        noProfiles: "Nessun profilo in OpenVPN Connect")

    static let ja = OpenVPNFeatureStrings(
        pageTitle: "VPN",
        hubDescription: "OpenVPN Connectの状態を確認し、パネルから接続・切断できます",
        panelDescription: "OpenVPN Connectの状態を確認し、パネルから接続・切断できます.",
        statusConnected: "接続済み",
        statusConnecting: "接続中…",
        statusDisconnected: "未接続",
        connect: "接続",
        disconnect: "切断",
        openApp: "OpenVPN Connectを開く",
        pinHint: "OpenVPN ConnectでPINを入力してください",
        profile: "プロファイル",
        appMissing: "OpenVPN Connectがインストールされていません",
        cannotControl: "OpenVPN Connectを操作できません",
        noProfiles: "OpenVPN Connectにプロファイルがありません")

    static let ko = OpenVPNFeatureStrings(
        pageTitle: "VPN",
        hubDescription: "OpenVPN Connect 상태를 확인하고 패널에서 연결하거나 연결을 끊습니다",
        panelDescription: "OpenVPN Connect 상태를 확인하고 패널에서 연결하거나 연결을 끊습니다.",
        statusConnected: "연결됨",
        statusConnecting: "연결 중…",
        statusDisconnected: "연결 안 됨",
        connect: "연결",
        disconnect: "연결 끊기",
        openApp: "OpenVPN Connect 열기",
        pinHint: "OpenVPN Connect에서 PIN을 입력하세요",
        profile: "프로필",
        appMissing: "OpenVPN Connect가 설치되어 있지 않습니다",
        cannotControl: "OpenVPN Connect를 제어할 수 없습니다",
        noProfiles: "OpenVPN Connect에 프로필이 없습니다")

    static let uk = OpenVPNFeatureStrings(
        pageTitle: "VPN",
        hubDescription: "Статус OpenVPN Connect, підключення й відключення просто з панелі",
        panelDescription: "Статус OpenVPN Connect, підключення й відключення просто з панелі.",
        statusConnected: "Підключено",
        statusConnecting: "Підключення…",
        statusDisconnected: "Відключено",
        connect: "Підключити",
        disconnect: "Відключити",
        openApp: "Відкрити OpenVPN Connect",
        pinHint: "Введіть PIN в OpenVPN Connect",
        profile: "Профіль",
        appMissing: "OpenVPN Connect не встановлено",
        cannotControl: "Не вдається керувати OpenVPN Connect",
        noProfiles: "В OpenVPN Connect немає профілів")

    static let zhHans = OpenVPNFeatureStrings(
        pageTitle: "VPN",
        hubDescription: "查看 OpenVPN Connect 状态，并在面板中连接或断开",
        panelDescription: "查看 OpenVPN Connect 状态，并在面板中连接或断开.",
        statusConnected: "已连接",
        statusConnecting: "正在连接…",
        statusDisconnected: "未连接",
        connect: "连接",
        disconnect: "断开连接",
        openApp: "打开 OpenVPN Connect",
        pinHint: "请在 OpenVPN Connect 中输入 PIN",
        profile: "配置文件",
        appMissing: "未安装 OpenVPN Connect",
        cannotControl: "无法控制 OpenVPN Connect",
        noProfiles: "OpenVPN Connect 中没有配置文件")

    static let zhTW = OpenVPNFeatureStrings(
        pageTitle: "VPN",
        hubDescription: "查看 OpenVPN Connect 狀態，並在面板中連線或中斷連線",
        panelDescription: "查看 OpenVPN Connect 狀態，並在面板中連線或中斷連線.",
        statusConnected: "已連線",
        statusConnecting: "連線中…",
        statusDisconnected: "未連線",
        connect: "連線",
        disconnect: "中斷連線",
        openApp: "開啟 OpenVPN Connect",
        pinHint: "請在 OpenVPN Connect 中輸入 PIN",
        profile: "設定檔",
        appMissing: "未安裝 OpenVPN Connect",
        cannotControl: "無法控制 OpenVPN Connect",
        noProfiles: "OpenVPN Connect 中沒有設定檔")

    static let zhHK = OpenVPNFeatureStrings(
        pageTitle: "VPN",
        hubDescription: "查看 OpenVPN Connect 狀態，並在面板中連線或中斷連線",
        panelDescription: "查看 OpenVPN Connect 狀態，並在面板中連線或中斷連線.",
        statusConnected: "已連線",
        statusConnecting: "連線中…",
        statusDisconnected: "未連線",
        connect: "連線",
        disconnect: "中斷連線",
        openApp: "開啟 OpenVPN Connect",
        pinHint: "請在 OpenVPN Connect 輸入 PIN",
        profile: "設定檔",
        appMissing: "未有安裝 OpenVPN Connect",
        cannotControl: "無法控制 OpenVPN Connect",
        noProfiles: "OpenVPN Connect 內沒有設定檔")
}
