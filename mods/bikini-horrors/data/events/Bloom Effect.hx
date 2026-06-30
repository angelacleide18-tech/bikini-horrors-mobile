// CREDITS TO LUNAR AND NEX FOR THESE SHADERS, BLOOM, SATURATION ETC.

public var bloom:CustomShader = null;
var bloomOnHud:Bool = false;

var bloomTween:FlxTween = null;
var curbloom:Float = 1;

var BLOOM_OFF_EPS:Float = 0.001;

function create() {
    if(!Options.shaderQualityAllows(1)) {
        disableScript();
        return;
    }

    var highShaders:Bool = Options.shaderQualityAllows(2);

    bloom = new CustomShader("bloom");

    // 关闭状态不要给 brightness = 1，否则会有亮度残留
    bloom.size = 0;
    bloom.brightness = 0;

    bloom.directions = highShaders ? 6 : 4;
    bloom.quality = highShaders ? 6 : 4;

    FlxG.camera.addShader(bloom);

    bloomOnHud = highShaders;
    if (bloomOnHud)
        camHUD.addShader(bloom);
}

function normalizeBloomSongName(value:String):String {
    if (value == null)
        return "";

    return value.toLowerCase().split(" ").join("").split("-").join("").split("_").join("");
}

function isBloomSong(song:String):Bool {
    var target:String = normalizeBloomSongName(song);
    var songName:String = PlayState.SONG == null || PlayState.SONG.meta == null ? "" : PlayState.SONG.meta.name;
    var songId:String = PlayState.instance == null ? "" : PlayState.instance.curSongID;

    return normalizeBloomSongName(songName) == target || normalizeBloomSongName(songId) == target;
}

function onEvent(eventEvent) {
    var params:Array = eventEvent.event.params;

    if (eventEvent.event.name == "Bloom Effect") {
        if (params[0] == false) {
            setBloom(params[1]);
        } else {
            if (bloomTween != null)
                bloomTween.cancel();

            var flxease:String = params[3] + (params[3] == "linear" ? "" : params[4]);
            var targetBloom:Float = params[1];

            bloomTween = FlxTween.num(
                curbloom,
                targetBloom,
                ((Conductor.crochet / 4) / 1000) * params[2],
                {
                    ease: Reflect.field(FlxEase, flxease),
                    onComplete: function(_) {
                        setBloom(targetBloom);
                    }
                },
                function(val:Float) {
                    setBloom(val);
                }
            );
        }
    }
}

function hardDisableBloom(storeValue:Float) {
    if (bloom == null)
        return;

    bloom.size = 0;

    // 关键：这里必须是 0，不要是 1
    bloom.brightness = 0;

    curbloom = storeValue;
}

function setBloom(bloom_effect:Float) {
    if (bloom == null)
        return;

    // bloom_effect 小于等于 1 都视为关闭
    // 0.001 / 1 / 1.0001 都不会留下亮度
    if (bloom_effect <= 1 + BLOOM_OFF_EPS) {
        hardDisableBloom(bloom_effect);
        return;
    }

    var highShaders:Bool = Options.shaderQualityAllows(2);
    var fertilityMedium:Bool = !highShaders && isBloomSong("fertility");

    var effect:Float = Math.max(bloom_effect, 1);

    if (highShaders)
        effect = Math.min(effect, 2.6);
    else if (fertilityMedium)
        effect = Math.min(effect, 1.85);
    else
        effect = Math.min(effect, 2.25);

    var bloomAmount:Float = Math.max(effect - 1, 0);

    var nextSize:Float = bloomAmount * (highShaders ? 2.55 : (fertilityMedium ? 1.75 : 2.35));

    if (nextSize <= BLOOM_OFF_EPS) {
        hardDisableBloom(bloom_effect);
        return;
    }

    bloom.size = nextSize;

    if (highShaders) {
        bloom.brightness = 1 + Math.min(bloomAmount, 1.6) * 0.34;
    } else if (fertilityMedium) {
        bloom.brightness = 1 + Math.min(bloomAmount, 0.85) * 0.22;
    } else {
        bloom.brightness = Math.max(Math.min(effect, 1.45), 1);
    }

    curbloom = bloom_effect;
}
