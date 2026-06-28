// Thanks Nex for msot of this script :3 - Chezzar
import flixel.math.FlxRect;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.ui.FlxBar.FlxBarFillDirection;
import flixel.ui.FlxBar;
import flixel.util.FlxAxes;
import flixel.FlxCamera;
import flixel.util.FlxColor;
import funkin.game.HealthIcon;
import flixel.FlxSprite;
import funkin.game.PlayState;

public var sonicMode:Bool = false;

static var healthColors = [0xFF000000, 0xFF000000];
var newBar:FlxSprite;
var _barRect:FlxRect = new FlxRect();

var falseHealth:Float = health;
var healthpercent:Float = falseHealth / maxHealth;
var xPos = 390;

public var cinematicTOP:FlxSprite;
public var cinematicLOWER:FlxSprite;

public var timeBar:FlxBar;
public var timePassedTxt:FunkinText;
public var totalTimeTxt:FunkinText;

public var angle : Float = 0;

public var rankTxt:FunkinText;

public var camMoveOffset:Float = 15;
public var camAngleOffset:Float = .3;

var stopPlayTweens:Bool = false;

var misses:Int = null;
var accuracy:Float = null;
var oldImagePath:String->String = null;
var madeInChinaHudLayoutReady:Bool = false;
var madeInChinaHudLastWidth:Float = -1;
var madeInChinaHudLastDownscroll:Bool = false;
var madeInChinaHudLastScoreText:String = "";
var madeInChinaHudLastAccuracyText:String = "";
var madeInChinaHudLastMissesText:String = "";
var madeInChinaHudCamera:FlxCamera = null;
var iAmBackHudLayoutReady:Bool = false;
var iAmBackHudLastWidth:Float = -1;
var iAmBackHudLastDownscroll:Bool = false;
var iAmBackHudLastScoreText:String = "";
var iAmBackHudLastAccuracyText:String = "";
var iAmBackHudLastMissesText:String = "";
var defaultHudLayoutReady:Bool = false;
var defaultHudLastWidth:Float = -1;
var defaultHudLastDownscroll:Bool = false;
var defaultHudLastSongId:String = "";
var defaultHudLastStageId:String = "";

var songSpecificHudSongs:Array<String> = [
    "madeinchina",
    "iamback",
    "spotting",
    "steamunlocked",
    "flintstone",
    "rumbeling",
    "vashamorir",
    "paracetamol",
    "upsmecaigo",
    "laplaya",
    "unheard",
    "nophonezone",
    "poolparti",
    "cucarachabob",
    "daddatel"
];

var songSpecificHudStages:Array<String> = [
    "basement",
    "bobcave",
    "void",
    "poja",
    "jefestein",
    "island",
    "girona",
    "fysd",
    "corruptedbottom",
    "lostremains",
    "poolparti",
    "unheared",
    "rentdue",
    "volcano"
];

function normalizeHudSongName(value:String):String {
    if (value == null)
        return "";

    return value.toLowerCase().split(" ").join("").split("-").join("").split("_").join("");
}

function isMadeInChinaSong():Bool {
    var songName = PlayState.SONG == null || PlayState.SONG.meta == null ? "" : PlayState.SONG.meta.name.toLowerCase();
    var songId = PlayState.instance == null ? "" : PlayState.instance.curSongID.toLowerCase();

    songName = normalizeHudSongName(songName);
    songId = normalizeHudSongName(songId);

    return songName == "madeinchina" || songId == "madeinchina";
}

function isIAmBackSong():Bool {
    var songName = PlayState.SONG == null || PlayState.SONG.meta == null ? "" : PlayState.SONG.meta.name.toLowerCase();
    var songId = PlayState.instance == null ? "" : PlayState.instance.curSongID.toLowerCase();

    songName = normalizeHudSongName(songName);
    songId = normalizeHudSongName(songId);

    return songName == "iamback" || songId == "iamback";
}

function getCurrentHudSongId():String {
    var songName = PlayState.SONG == null || PlayState.SONG.meta == null ? "" : PlayState.SONG.meta.name;
    var songId = PlayState.instance == null ? "" : PlayState.instance.curSongID;
    var normalizedId = normalizeHudSongName(songId);
    return normalizedId == "" ? normalizeHudSongName(songName) : normalizedId;
}

function getCurrentHudStageId():String {
    return normalizeHudSongName(PlayState.instance == null ? "" : PlayState.instance.curStage);
}

function usesSongSpecificHud():Bool {
    var songId = getCurrentHudSongId();
    var stageId = getCurrentHudStageId();
    return songSpecificHudSongs.contains(songId) || songSpecificHudStages.contains(stageId);
}

function getMadeInChinaHudCamera():FlxCamera {
    if (madeInChinaHudCamera == null || madeInChinaHudCamera.width != FlxG.width || madeInChinaHudCamera.height != FlxG.height) {
        if (madeInChinaHudCamera != null)
            FlxG.cameras.remove(madeInChinaHudCamera, true);

        madeInChinaHudCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height);
        madeInChinaHudCamera.bgColor = 0x00000000;
        FlxG.cameras.add(madeInChinaHudCamera, false);
        madeInChinaHudLayoutReady = false;
    }

    return madeInChinaHudCamera;
}

function layoutMadeInChinaHud() {
    if (!isMadeInChinaSong())
        return;

    var hudCam = getMadeInChinaHudCamera();
    var downscroll:Bool = camHUD != null && camHUD.downscroll;
    var needsLayout:Bool = (!madeInChinaHudLayoutReady || madeInChinaHudLastWidth != FlxG.width || madeInChinaHudLastDownscroll != downscroll);
    var topY:Float = 10;
    var padding:Float = 18;
    var spacing:Float = 10;
    var scoreWidth:Float = Math.max(150, FlxG.width * 0.22);
    var accuracyWidth:Float = Math.max(190, FlxG.width * 0.26);
    var missesWidth:Float = Math.max(170, FlxG.width * 0.2);

    for (txt in [scoreTxt, accuracyTxt, missesTxt]) {
        if (txt == null)
            continue;

        if (needsLayout) {
            txt.cameras = [hudCam];
            txt.scrollFactor.set();
            txt.font = Paths.font("KrabbyPatty.otf");
            txt.size = 18;
            txt.scale.set(1, 1);
            txt.color = 0xFFFFFFFF;
            txt.borderStyle = FlxTextBorderStyle.OUTLINE;
            txt.borderColor = FlxColor.BLACK;
            txt.borderSize = 1.5;
            txt.wordWrap = false;
            txt.antialiasing = true;
        }
        txt.visible = true;
    }

    if (scoreTxt != null) {
        scoreTxt.x = padding;
        scoreTxt.y = topY;
        scoreTxt.fieldWidth = scoreWidth;
        scoreTxt.alignment = "left";
        if (needsLayout || madeInChinaHudLastScoreText != scoreTxt.text) {
            scoreTxt.updateHitbox();
            madeInChinaHudLastScoreText = scoreTxt.text;
        }
    }

    if (accuracyTxt != null) {
        accuracyTxt.x = padding + scoreWidth + spacing;
        accuracyTxt.y = topY;
        accuracyTxt.fieldWidth = accuracyWidth;
        accuracyTxt.alignment = "left";
        if (needsLayout || madeInChinaHudLastAccuracyText != accuracyTxt.text) {
            accuracyTxt.updateHitbox();
            madeInChinaHudLastAccuracyText = accuracyTxt.text;
        }
    }

    if (missesTxt != null) {
        missesTxt.x = FlxG.width - padding - missesWidth;
        missesTxt.y = topY;
        missesTxt.fieldWidth = missesWidth;
        missesTxt.alignment = "right";
        if (needsLayout || madeInChinaHudLastMissesText != missesTxt.text) {
            missesTxt.updateHitbox();
            madeInChinaHudLastMissesText = missesTxt.text;
        }
    }

    madeInChinaHudLayoutReady = true;
    madeInChinaHudLastWidth = FlxG.width;
    madeInChinaHudLastDownscroll = downscroll;

    for (txt in [timePassedTxt, totalTimeTxt, rankTxt]) {
        if (txt == null)
            continue;

        txt.visible = false;
        txt.alpha = 0;
    }

    if (timeBar != null) {
        timeBar.visible = false;
        timeBar.alpha = 0;
    }
}

function destroy() {
    if (madeInChinaHudCamera != null) {
        FlxG.cameras.remove(madeInChinaHudCamera, true);
        madeInChinaHudCamera = null;
    }
}

function onEvent(eventEvent)
{
    if (sonicMode) return;

    if (eventEvent.event.name == "Stop Play Tweens"){
        trace("event received");
        trace(eventEvent.event.name);
        trace(eventEvent.event.params[0]);
        stopPlayTweens = eventEvent.event.params[0];
    }
}

public function clockFormat(milliseconds:Float):String {
    return "";
}

function applyKadeTextStyle(txt:FunkinText, big:Bool = false) {
    if (txt == null) return;

    txt.font = Paths.font("KrabbyPatty.otf");
    txt.size = big ? 24 : 20;
    txt.color = 0xFFFFFFFF;
    txt.borderStyle = FlxTextBorderStyle.OUTLINE;
    txt.borderColor = FlxColor.BLACK;
    txt.borderSize = big ? 2.5 : 2;
    txt.scale.set(1, 1);
    txt.wordWrap = false;
    txt.antialiasing = true;
    txt.updateHitbox();
}

function layoutIAmBackHudText() {
    var downscroll:Bool = camHUD != null && camHUD.downscroll;
    var needsLayout:Bool = (!iAmBackHudLayoutReady || iAmBackHudLastWidth != FlxG.width || iAmBackHudLastDownscroll != downscroll);
    var topY:Float = 12;
    var center:Float = FlxG.width * 0.5;
    var accuracyWidth:Float = Math.max(320, FlxG.width * 0.22);
    var missesWidth:Float = Math.max(180, FlxG.width * 0.12);
    var scoreWidth:Float = Math.max(260, FlxG.width * 0.17);

    for (txt in [accuracyTxt, missesTxt, scoreTxt]) {
        if (txt == null)
            continue;

        if (needsLayout) {
            txt.font = Paths.font("KrabbyPatty.otf");
            txt.size = 20;
            txt.scale.set(1, 1);
            txt.color = 0xFFFFFFFF;
            txt.borderStyle = FlxTextBorderStyle.OUTLINE;
            txt.borderColor = FlxColor.BLACK;
            txt.borderSize = 2;
            txt.wordWrap = false;
            txt.antialiasing = true;
        }

        txt.y = topY;
        txt.visible = true;
    }

    if (accuracyTxt != null) {
        accuracyTxt.x = center - 340;
        accuracyTxt.fieldWidth = accuracyWidth;
        accuracyTxt.alignment = "left";
        if (needsLayout || iAmBackHudLastAccuracyText != accuracyTxt.text) {
            accuracyTxt.updateHitbox();
            iAmBackHudLastAccuracyText = accuracyTxt.text;
        }
    }

    if (missesTxt != null) {
        missesTxt.x = center - 12;
        missesTxt.fieldWidth = missesWidth;
        missesTxt.alignment = "left";
        if (needsLayout || iAmBackHudLastMissesText != missesTxt.text) {
            missesTxt.updateHitbox();
            iAmBackHudLastMissesText = missesTxt.text;
        }
    }

    if (scoreTxt != null) {
        scoreTxt.x = center + 245;
        scoreTxt.fieldWidth = scoreWidth;
        scoreTxt.alignment = "left";
        if (needsLayout || iAmBackHudLastScoreText != scoreTxt.text) {
            scoreTxt.updateHitbox();
            iAmBackHudLastScoreText = scoreTxt.text;
        }
    }

    iAmBackHudLayoutReady = true;
    iAmBackHudLastWidth = FlxG.width;
    iAmBackHudLastDownscroll = downscroll;
}

function layoutDefaultHudText() {
    if (isMadeInChinaSong())
        return;
    if (isIAmBackSong()) {
        layoutIAmBackHudText();
        return;
    }
    if (usesSongSpecificHud())
        return;
    if (healthBarBG == null)
        return;

    var downscroll:Bool = camHUD != null && camHUD.downscroll;
    var songId:String = getCurrentHudSongId();
    var stageId:String = getCurrentHudStageId();
    var needsLayout:Bool = (!defaultHudLayoutReady || defaultHudLastWidth != FlxG.width || defaultHudLastDownscroll != downscroll || defaultHudLastSongId != songId || defaultHudLastStageId != stageId);

    if (!needsLayout)
        return;

    var baseX:Float = healthBarBG.x + 50;
    var baseY:Float = healthBarBG.y + 30;
    var fieldWidth:Float = Math.max(320, healthBarBG.width - 100);

    for (txt in [accuracyTxt, missesTxt, scoreTxt]) {
        if (txt == null)
            continue;

        txt.x = baseX;
        txt.y = baseY;
        txt.fieldWidth = fieldWidth;
        txt.wordWrap = false;
        txt.visible = true;
    }

    if (accuracyTxt != null)
        accuracyTxt.alignment = "left";
    if (missesTxt != null)
        missesTxt.alignment = "center";
    if (scoreTxt != null)
        scoreTxt.alignment = "right";

    for (txt in [accuracyTxt, missesTxt, scoreTxt])
        if (txt != null)
            txt.updateHitbox();

    defaultHudLayoutReady = true;
    defaultHudLastWidth = FlxG.width;
    defaultHudLastDownscroll = downscroll;
    defaultHudLastSongId = songId;
    defaultHudLastStageId = stageId;
}

function create() {
    Note.swagWidth = 112; 
    PauseSubState.script = "data/states/pauseMenu.hx";
}

function postCreate() {
    if (sonicMode) return;
    madeInChinaHudLayoutReady = false;
    iAmBackHudLayoutReady = false;
    defaultHudLayoutReady = false;
    minDigitDisplay = -1;

    if (!usesSongSpecificHud()) {
        healthBar.visible = true;
        healthBarBG.visible = true;
    }
    if (healthBarBG != null)
        healthBarBG.antialiasing = true;
    doIconBop = true;

    comboGroup.setPosition(FlxG.width / 2 - 57, 120);

    var hudTexts = [accuracyTxt, missesTxt, scoreTxt, timePassedTxt, totalTimeTxt];
    var originalX = [];
    var originalFieldWidth = [];
    var originalAlignment = [];

    for (txt in hudTexts) {
        originalX.push(txt == null ? 0 : txt.x);
        originalFieldWidth.push(txt == null ? 0 : txt.fieldWidth);
        originalAlignment.push(txt == null ? "center" : txt.alignment);
    }

    var textIndex:Int = 0;
    for (txt in hudTexts) {
        var currentTextIndex:Int = textIndex;
        textIndex += 1;
        if (txt == null) continue;

        applyKadeTextStyle(txt, txt == totalTimeTxt);
        txt.color = 0xFFFFFFFF;
        txt.alignment = originalAlignment[currentTextIndex];
        txt.fieldWidth = originalFieldWidth[currentTextIndex];
        txt.x = originalX[currentTextIndex];

        txt.updateHitbox();
        add(txt);
    }

    layoutDefaultHudText();
    layoutMadeInChinaHud();
}

function onCameraMove(event) {
    if (sonicMode) return;
    if (event.strumLine?.characters[0] != null && ! stopPlayTweens) {
        var suffix = event.strumLine.animSuffix;
        switch (event.strumLine.characters[0].animation.name) {
            case "singLEFT" + suffix: event.position.x -= camMoveOffset; angle = -camAngleOffset;
            case "singDOWN" + suffix: event.position.y += camMoveOffset; angle = -camAngleOffset/2;
            case "singUP" + suffix: event.position.y -= camMoveOffset; angle = camAngleOffset/2;
            case "singRIGHT" + suffix: event.position.x += camMoveOffset; angle = camAngleOffset;
            default: angle = 0;
        }
    }
}

function onNoteHit(event){
    if (sonicMode) return;

        event.ratingScale = 0.5;

}

function onPlayerHit(event)
{
    if (!sonicMode) return;

    var name:String;

    switch (event.rating)
    {
        case "sick": name = "sick";
        case "good": name = "good";
        case "bad": name = "bad";
        case "shit": name = "shit";
        default: name = "sick";
    }

    spawnSonicRating(
        name,
        FlxG.width * 0.4,
        FlxG.height * 0.35
    );
}

function spawnHitMsText(x:Float, y:Float)
{
    var ms:Int = FlxG.random.int(-100000, 9999999999999);

    var txt:FunkinText = new FunkinText(x, y, 0, ms + "ms");
    txt.setFormat(Paths.font("Camera.ttf"), 30, 0x00FFFF, true);

    txt.borderStyle = FlxTextBorderStyle.OUTLINE;
    txt.borderColor = FlxColor.BLACK;
    txt.borderSize = 0.5;

    txt.antialiasing = true;
    txt.scrollFactor.set(0, 0);
    txt.cameras = [camGame];

    add(txt);

    FlxTween.tween(txt, { y: y - 40, alpha: 0 }, 0.6, {
        ease: FlxEase.quadOut,
        onComplete: (_) -> txt.destroy()
    });
}


function spawnSonicRating(name:String, x:Float, y:Float)
{
    var spr = new FlxSprite(x, y);

    spr.loadGraphic(Paths.image("game/score/kade_" + name));
    
    spr.cameras = [camGame];
    spr.antialiasing = true;
    spr.x += 800;
    spr.y -= 50;

    spr.velocity.y = -60;
    spr.velocity.x = FlxG.random.float(-20, 20);
    spr.acceleration.y = 200;

    spr.scale.set(0.8, 0.8);
    spr.alpha = 1;

    add(spr);

    FlxTween.tween(spr, {alpha: 0}, 0.4, {
        startDelay: 0.3,
        onComplete: (_) -> spr.kill()
    });

        var x = spr.x - 700;
        var y = spr.y + 60;

        spawnHitMsText(x, y);
}


function postUpdate() {
    layoutDefaultHudText();
    layoutMadeInChinaHud();


    if (sonicMode){
        comboGroup.forEachAlive(function(spr) {
            spr.visible = false;
            
        });
        return;
    } 

    var misses:Int = PlayState.instance.misses;
    var accuracy:Float = PlayState.instance.accuracy;

    comboGroup.forEachAlive(function(spr) {
        if (spr.camera != camHUD) spr.camera = camHUD;
        if (spr.acceleration.y != 0) {
            spr.acceleration.y = 0;
            spr.velocity.set(0, 0);

            FlxTween.cancelTweensOf(spr);

            var randomScale:Float = FlxG.random.float(0.7, 0.9);
            FlxTween.tween(spr, {'scale.x': spr.scale.x*randomScale, 'scale.y': spr.scale.x*randomScale}, FlxG.random.float(.075, .125), {ease: FlxEase.circInOut, onComplete: (_) -> {
                FlxTween.tween(spr, {'scale.x': spr.scale.x*.4, 'scale.y': spr.scale.x*.4, alpha: 0, angle: FlxG.random.float(0, 0) * FlxG.random.sign()}, .1+FlxG.random.float(.255, .255), {ease: FlxEase.circInOut, onComplete: (_) -> {
                    spr.kill();
                }});
            }});
        }
    });
    if (! stopPlayTweens){
        camGame.angle = CoolUtil.fpsLerp(camGame.angle, angle, 1/10);
    }


    if (FlxG.save.data.fc == true) {
        if (misses > 0) {
            gameOver();
        }
    }

    if (FlxG.save.data.pm == true) {
        if ((accuracy >= 0 && accuracy < 1.0)) {
            gameOver();
        }
    }
}


override function onSongEnd()
{
    trace("Song ended successfully");

    if (FlxG.save.data.clearedSongs == null)
    {
        FlxG.save.data.clearedSongs = [
            "guater-game",
            "f-is-for-fevil",
            "sunderwater",
            "catch-and-fish",
            "bubbletwister"
        ];
    }

    var currentSongName:String = PlayState.SONG.meta.name.toLowerCase();

    if (!FlxG.save.data.clearedSongs.contains(currentSongName))
    {
        FlxG.save.data.clearedSongs.push(currentSongName);
        FlxG.save.flush();
    }
}
