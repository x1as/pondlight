// PONDLIGHT web bridge: Yandex Games SDK when the game runs on Yandex, a harmless no-op anywhere else.
// Godot polls window.PL through JavaScriptBridge (see scripts/autoload/platform_service.gd).
window.PL = {
	ysdk: null, lang: "", paused: false, reward: 0, ready_sent: false, gameplay: false,
	init: function () {
		if (typeof YaGames === "undefined") { return; }
		YaGames.init().then(function (s) {
			PL.ysdk = s;
			try { PL.lang = s.environment.i18n.lang || ""; } catch (e) {}
		}).catch(function () {});
	},
	has_sdk: function () { return PL.ysdk ? 1 : 0; },
	loaded: function () {
		if (PL.ready_sent || !PL.ysdk) { return; }
		try { PL.ysdk.features.LoadingAPI.ready(); PL.ready_sent = true; } catch (e) {}
	},
	set_gameplay: function (on) {
		if (!PL.ysdk || PL.gameplay === on) { return; }
		PL.gameplay = on;
		try { var g = PL.ysdk.features.GameplayAPI; if (on) { g.start(); } else { g.stop(); } } catch (e) {}
	},
	fullscreen: function () {
		if (!PL.ysdk) { return; }
		PL.paused = true;
		PL.ysdk.adv.showFullscreenAdv({callbacks: {
			onClose: function () { PL.paused = false; },
			onError: function () { PL.paused = false; }
		}});
	},
	rewarded: function () {
		if (!PL.ysdk) { PL.reward = -1; return; }
		PL.reward = 0;
		PL.paused = true;
		PL.ysdk.adv.showRewardedVideo({callbacks: {
			onRewarded: function () { PL.reward = 1; },
			onClose: function () { PL.paused = false; if (PL.reward === 0) { PL.reward = -1; } },
			onError: function () { PL.paused = false; PL.reward = -1; }
		}});
	},
	should_pause: function () { return (PL.paused || document.hidden) ? 1 : 0; }
};
PL.init();
