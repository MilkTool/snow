package snow.systems.audio;

import snow.types.Types;
import snow.systems.assets.Asset;
import snow.systems.audio.AudioInstance;
import snow.api.Promise;
import snow.api.Debug.*;
import snow.api.Emitter;


@:allow(snow.Snow)
class Audio {

        /** access to snow from subsystems */
    public var app : Snow;
        /** access to module specific implementation */
    public var module : ModuleAudio;
        /** Set to false to stop any and all processing in the audio system */
    public var active : Bool = false;

    var emitter : Emitter<AudioEvent>;

        /** constructed internally, use `app.audio` */
    function new(_app:Snow) {

        app = _app;
        module = new ModuleAudio(app);
        emitter = new Emitter();
        active = module.active;

    }

//Public API

    @:generic
    public function on<T>(_event:AudioEvent, _handler:T->Void) : Void {
    
        emitter.on(_event, _handler);
    
    }
    
    @:generic
    public function off<T>(_event:AudioEvent, _handler:T->Void) : Bool {
    
        return emitter.off(_event, _handler);
    
    }
        
    @:generic
    public function emit<T>(_event:AudioEvent, _data:T) : Void {
    
        emitter.emit(_event, _data);
    
    }
    
    public function play(_source:AudioSource, ?_volume:Float=1.0, ?_paused:Bool=false) : AudioHandle {

        assert(_source != null, 'audio source must not be null');

        if(!active) {
            return -1;
        }

        return module.play(_source, _volume, _paused);

    }

        /** play and loop a sound source, indefinitely. Use stop to end it. */
    public function loop(_source:AudioSource, ?_volume:Float=1.0, ?_paused:Bool=false) : AudioHandle {
        
        assert(_source != null, 'audio source must not be null');

        if(!active) {
            return -1;
        }

        return module.loop(_source, _volume, _paused);

    }

    public function pause(_handle:AudioHandle) : Void {
        if(!active || _handle == null) return;
        module.pause(_handle);
    }

    public function unpause(_handle:AudioHandle) : Void {
        if(!active || _handle == null) return;
        module.unpause(_handle);
    }

    public function stop(_handle:AudioHandle) : Void {
        if(!active || _handle == null) return;
        module.stop(_handle);
    }

    public function volume(_handle:AudioHandle, _volume:Float) : Void {
        if(!active || _handle == null) return;
        module.volume(_handle, _volume);
    }

    public function pan(_handle:AudioHandle, _pan:Float) : Void {
        if(!active || _handle == null) return;
        module.pan(_handle, _pan);
    }

    public function pitch(_handle:AudioHandle, _pitch:Float) : Void {
        if(!active || _handle == null) return;
        module.pitch(_handle, _pitch);
    }

    public function position(_handle:AudioHandle, _position:Float) : Void {
        if(!active || _handle == null) return;
        module.position(_handle, _position);
    }

    public function state_of(_handle:AudioHandle) : AudioState {
        return module.state_of(_handle);
    }

    public function loop_of(_handle:AudioHandle) : Bool {
        assert(active, 'audio is suspended, queries are invalid');
        return module.loop_of(_handle);
    }

    public function instance_of(_handle:AudioHandle) : AudioInstance {
        assert(active, 'audio is suspended, queries are invalid');
        return module.instance_of(_handle); 
    }

    public function volume_of(_handle:AudioHandle) : Float {
        assert(active, 'audio is suspended, queries are invalid');
        return module.volume_of(_handle); 
    }

    public function pan_of(_handle:AudioHandle) : Float {
        assert(active, 'audio is suspended, queries are invalid');
        return module.pan_of(_handle); 
    }

    public function pitch_of(_handle:AudioHandle) : Float {
        assert(active, 'audio is suspended, queries are invalid');
        return module.pitch_of(_handle); 
    }

    public function position_of(_handle:AudioHandle) : Float {
        assert(active, 'audio is suspended, queries are invalid');
        return module.position_of(_handle); 
    }

    public function suspend() : Void {

        if(!active) {
            return;
        }

        _debug("suspending sound context");
        active = false;
        module.suspend();

    }

    public function resume() : Void {

        if(active || !module.active) {
            return;
        }

        _debug("resuming sound context");
        active = true;
        module.resume();

    }

//Internal

        /** Called by Snow when a system event is dispatched */
    function onevent( _event:SystemEvent ) {

        module.onevent(_event);

        if(_event.type == se_freeze) {
            suspend();
        } else if(_event.type == se_unfreeze) {
            resume();
        } else if(_event.type == se_window) {
            switch(_event.window.type) {
                case WindowEventType.we_minimized:
                    suspend();
                case WindowEventType.we_restored:
                    resume();
                case _: {}
            }
        }

    }

        /** Called by Snow, cleans up sounds/system */
    function shutdown() {

        active = false;
        module.shutdown();

    }

}
