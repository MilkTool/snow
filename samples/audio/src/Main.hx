
import snow.api.Debug.*;
import snow.types.Types;
import snow.modules.opengl.GL;

typedef UserConfig = {}

@:log_as('app')
class Main extends snow.App {

    function new() {}

    override function config( config:AppConfig ) : AppConfig {

        config.window.title = 'snow audio';

        return config;

    } //config


    override function ready() {

        log('ready');

        app.assets.audio('assets/sound.wav')
            .then(sound_loaded).error(function(e) log(e));

    } //ready

    var sound : AssetAudio;

    function sound_loaded(asset:AssetAudio) {
        sound = asset;
        log('`${sound.audio.id}` : ' + audio);
    }

    override function onmouseup( x:Int, y:Int, button:Int, _, _ ) {

        if(sound != null) {
            var _handle = app.audio.play(sound);
            trace(_handle);
        }

    } //onmouseup

    override function onkeyup( keycode:Int, _,_, mod:ModState, _,_ ) {

        
        if( keycode == Key.escape ) {
            app.shutdown();
        }

    } //onkeyup

    override function tick( delta:Float ) {

        GL.clearColor(1.0,1.0,1.0,1.0);
        GL.clear(GL.COLOR_BUFFER_BIT);

    } //

} //Main
