package snow.systems.input;

import snow.types.Types;
import snow.api.Debug.assert;

import ceramic.IntBoolMap;
import ceramic.IntFloatMap;
import ceramic.IntMap;

/** The snow input system. Accessed via `app.input` */
@:allow(snow.Snow)
class Input {

        /** access to snow from subsystems */
    var app : Snow;

        /** An internal value for how many gamepads to pre-set up at creation time */
    var gamepad_init_count = 16;
        /** A prealloacated input event for dispatching */
    var event: InputEvent;
    var key_event: KeyEvent;
    var text_event: TextEvent;
    var mouse_event: MouseEvent;
    var touch_event: TouchEvent;
    var gamepad_event: GamepadEvent;

    @:allow(snow.core.Runtime)
    var mod_state: ModState;

    var tmp_int_array: Array<Int> = [];

        /** Constructed internally, use `app.input` */
    function new( _app:Snow ) {

        app = _app;
        event = new InputEvent();
        key_event = new KeyEvent();
        text_event = new TextEvent();
        mouse_event = new MouseEvent();
        touch_event = new TouchEvent();
        gamepad_event = new GamepadEvent();
        mod_state = new ModState();
        mod_state.none = true;

        //keys

            key_code_pressed = new IntBoolMap(16, 0.5, true);
            key_code_down = new IntBoolMap();
            key_code_released = new IntBoolMap(16, 0.5, true);

            scan_code_pressed = new IntBoolMap(16, 0.5, true);
            scan_code_down = new IntBoolMap();
            scan_code_released = new IntBoolMap(16, 0.5, true);

        //mouse

            mouse_button_pressed = new IntBoolMap(16, 0.5, true);
            mouse_button_down = new IntBoolMap();
            mouse_button_released = new IntBoolMap(16, 0.5, true);

        //gamepad

            gamepad_button_pressed = new IntMap(16, 0.5, true);
            gamepad_button_down = new IntMap();
            gamepad_button_released = new IntMap(16, 0.5, true);
            gamepad_axis_values = new IntMap();
            
            for(i in 0...gamepad_init_count) {
                gamepad_button_pressed.set(i, new IntBoolMap(16, 0.5, true));
                gamepad_button_down.set(i, new IntBoolMap(16, 0.5, true));
                gamepad_button_released.set(i, new IntBoolMap(16, 0.5, true));
                gamepad_axis_values.set(i, new IntFloatMap(16, 0.5, true));
            }

        //touch

            touches_down = new IntBoolMap();

    }

        /** Destroy and clean up etc. */
    function shutdown() {

    }

//Public facing API


    //Key immediate style access
     //
            /** returns true if the `Key` value was pressed in the latest frame */
        public function keypressed( _code:Int ) : Bool {
            return key_code_pressed.exists(_code);
        }

            /** returns true if the `Key` value was released in the latest frame */
        public function keyreleased( _code:Int ) : Bool {
            return key_code_released.exists(_code);
        }

            /** returns true if the `Key` value is down at the time of calling this */
        public function keydown( _code:Int ) : Bool {
           return key_code_down.exists(_code);
        }

            /** returns true if the `Scan` value was pressed in the latest frame */
        public function scanpressed( _code:Int ) : Bool {
            return scan_code_pressed.exists(_code);
        }

            /** returns true if the `Scan` value was released in the latest frame */
        public function scanreleased( _code:Int ) : Bool {
            return scan_code_released.exists(_code);
        }

            /** returns true if the `Scan` value is down at the time of calling this */
        public function scandown( _code:Int ) : Bool {
           return scan_code_down.exists(_code);
        }

    //Mouse immediate style access
      //
            /** returns true if the mouse button was pressed in the latest frame */
        public function mousepressed( _button:Int ) : Bool {
            return mouse_button_pressed.exists(_button);
        }

            /** returns true if the mouse button was released in the latest frame */
        public function mousereleased( _button:Int ) : Bool {
            return mouse_button_released.exists(_button);
        }

            /** returns true if the mouse button value is down at the time of calling this */
        public function mousedown( _button:Int ) : Bool {
           return mouse_button_down.exists(_button);
        }

    //Gamepad immediate style access
     //
            /** returns true if the mouse button was pressed in the latest frame */
        public function gamepadpressed( _gamepad:Int, _button:Int ) : Bool {

            var _gamepad_state = gamepad_button_pressed.get(_gamepad);
            return _gamepad_state != null ? _gamepad_state.exists(_button) : false;

        }

            /** returns true if the gamepad button was released in the latest frame */
        public function gamepadreleased( _gamepad:Int, _button:Int ) : Bool {

            var _gamepad_state = gamepad_button_released.get(_gamepad);
            return _gamepad_state != null ? _gamepad_state.exists(_button) : false;

        }

            /** returns true if the gamepad button value is down at the time of calling this */
        public function gamepaddown( _gamepad:Int, _button:Int ) : Bool {

            var _gamepad_state = gamepad_button_down.get(_gamepad);
            return _gamepad_state != null ? _gamepad_state.exists(_button) : false;

        }

            /** returns true if the gamepad button value is down at the time of calling this */
        public function gamepadaxis( _gamepad:Int, _axis:Int ) : Float {

            var _gamepad_state = gamepad_axis_values.get(_gamepad);
            if(_gamepad_state != null) {
                if(_gamepad_state.exists(_axis)) {
                    return _gamepad_state.get(_axis);
                }
            }

            return 0;

        }

        /** manually dispatch a key down event through the system, delivered to the app handlers, internal and external */

    public function dispatch_key_down_event( keycode:Int, scancode:Int, repeat:Bool, mod:ModState, timestamp:Float, window_id:Int ) {
        //

            //only do the realtime flags if not key repeat
        if(!repeat) {
                //flag the key as pressed, but unprocessed (false)
            key_code_pressed.set(keycode, false);
                //flag it as down, because keyup removes it
            key_code_down.set(keycode, true);
                //flag the scan as pressed, but unprocessed (false)
            scan_code_pressed.set(scancode, false);
                //flag it as down, because keyup removes it
            scan_code_down.set(scancode, true);
        }

            //dispatch the event
        key_event.set(ke_down, keycode, scancode, repeat, mod);
        event.set_key(key_event, window_id, timestamp);
        app.dispatch_input_event(event);

            //call the app directly
        app.host.onkeydown(keycode, scancode, repeat, mod, timestamp, window_id);

    }

        /** manually dispatch a key up event through the system, delivered to the app handlers, internal and external */
    public function dispatch_key_up_event( keycode:Int, scancode:Int, repeat:Bool, mod:ModState, timestamp:Float, window_id:Int ) {
        //

            //flag it as released but unprocessed
        key_code_released.set(keycode, false);
            //remove the down flag
        key_code_down.remove(keycode);

            //flag it as released but unprocessed
        scan_code_released.set(scancode, false);
            //remove the down flag
        scan_code_down.remove(scancode);


            //dispatch the event
        key_event.set(ke_up, keycode, scancode, repeat, mod);
        event.set_key(key_event, window_id, timestamp);
        app.dispatch_input_event(event);

            //call the app directly
        app.host.onkeyup(keycode, scancode, repeat, mod, timestamp, window_id);

    }

        /** manually dispatch a text event through the system, delivered to the app handlers, internal and external */
    public function dispatch_text_event( text:String, start:Int, length:Int, type:TextEventType, timestamp:Float, window_id:Int ) {

        text_event.set(type, text, start, length);
        event.set_text(text_event, window_id, timestamp);
        app.dispatch_input_event(event);

        app.host.ontextinput( text, start, length, type, timestamp, window_id );

    }


        /** manually dispatch a mouse move event through the system, delivered to the app handlers, internal and external */
    public function dispatch_mouse_move_event( x:Int, y:Int, xrel:Int, yrel:Int, timestamp:Float, window_id:Int ) {

        mouse_event.set(me_move, x, y, xrel, yrel, 0, 0, 0);
        event.set_mouse(mouse_event, window_id, timestamp);
        app.dispatch_input_event(event);

        app.host.onmousemove( x, y, xrel, yrel, timestamp, window_id );

    }

        /** manually dispatch a mouse button down event through the system, delivered to the app handlers, internal and external */
    public function dispatch_mouse_down_event( x:Int, y:Int, button:Int, timestamp:Float, window_id:Int ) {
        //
            //flag the button as pressed, but unprocessed (false)
        mouse_button_pressed.set(button, false);
            //flag it as down, because mouseup removes it
        mouse_button_down.set(button, true);

        mouse_event.set(me_down, x, y, 0, 0, button, 0, 0);
        event.set_mouse(mouse_event, window_id, timestamp);
        app.dispatch_input_event(event);

        app.host.onmousedown( x, y, button, timestamp, window_id );

    }

        /** manually dispatch a mouse button up event through the system, delivered to the app handlers, internal and external */
    public function dispatch_mouse_up_event( x:Int, y:Int, button:Int, timestamp:Float, window_id:Int ) {
        //
            //flag it as released but unprocessed
        mouse_button_released.set(button, false);
            //remove the down flag
        mouse_button_down.remove(button);

        mouse_event.set(me_up, x, y, 0, 0, button, 0, 0);
        event.set_mouse(mouse_event, window_id, timestamp);
        app.dispatch_input_event(event);


        app.host.onmouseup( x, y, button, timestamp, window_id );

    }

        /** manually dispatch a mouse wheel event through the system, delivered to the app handlers, internal and external */
    public function dispatch_mouse_wheel_event( x:Float, y:Float, timestamp:Float, window_id:Int ) {

        mouse_event.set(me_wheel, 0, 0, 0, 0, 0, x, y);
        event.set_mouse(mouse_event, window_id, timestamp);
        app.dispatch_input_event(event);

        app.host.onmousewheel( x, y, timestamp, window_id );

    }

        /** manually dispatch a touch down through the system, delivered to the app handlers, internal and external */
    public function dispatch_touch_down_event( x:Float, y:Float, dx:Float, dy:Float, touch_id:Int, timestamp:Float ) {

        if(!touches_down.exists(touch_id)) {
            touch_count++;
            touches_down.set(touch_id, true);
        }

        touch_event.set(te_down, touch_id, x, y, dx, dy);
        event.set_touch(touch_event, timestamp);
        app.dispatch_input_event(event);

        app.host.ontouchdown( x, y, dx, dy, touch_id, timestamp );

    }

        /** manually dispatch a touch up through the system, delivered to the app handlers, internal and external */
    public function dispatch_touch_up_event( x:Float, y:Float, dx:Float, dy:Float, touch_id:Int, timestamp:Float ) {

        touch_event.set(te_up, touch_id, x, y, dx, dy);
        event.set_touch(touch_event, timestamp);
        app.dispatch_input_event(event);

        app.host.ontouchup( x, y, dx, dy, touch_id, timestamp );

        if(touches_down.remove(touch_id)) {
            touch_count--;
        }

    }

        /** manually dispatch a touch move through the system, delivered to the app handlers, internal and external */
    public function dispatch_touch_move_event( x:Float, y:Float, dx:Float, dy:Float, touch_id:Int, timestamp:Float ) {
        
        touch_event.set(te_move, touch_id, x, y, dx, dy);
        event.set_touch(touch_event, timestamp);
        app.dispatch_input_event(event);

        app.host.ontouchmove( x, y, dx, dy, touch_id, timestamp );

    }

        /** manually dispatch a gamepad axis event through the system, delivered to the app handlers, internal and external */
    public function dispatch_gamepad_axis_event( gamepad:Int, axis:Int, value:Float, timestamp:Float ) {

        assert(gamepad_axis_values.exists(gamepad), 'gamepad with id $gamepad not pre-inited? Is gamepad_init_count too low, or the gamepad id not sequential from 0?');

            //update the axis value
        gamepad_axis_values.get(gamepad).set(axis, value);

        gamepad_event.set_axis(gamepad, axis, value);
        event.set_gamepad(gamepad_event, timestamp);
        app.dispatch_input_event(event);

        app.host.ongamepadaxis( gamepad, axis, value, timestamp );

    }

        /** manually dispatch a gamepad button down event through the system, delivered to the app handlers, internal and external */
    public function dispatch_gamepad_button_down_event( gamepad:Int, button:Int, value:Float, timestamp:Float ) {

        assert(gamepad_button_pressed.exists(gamepad), 'gamepad with id $gamepad not pre-inited? Is gamepad_init_count too low, or the gamepad id not sequential from 0?');
        assert(gamepad_button_down.exists(gamepad), 'gamepad with id $gamepad not pre-inited? Is gamepad_init_count too low, or the gamepad id not sequential from 0?');

            //flag it as released but unprocessed
        gamepad_button_pressed.get(gamepad).set(button, false);
            //flag it as down, because gamepadup removes it
        gamepad_button_down.get(gamepad).set(button, true);

        gamepad_event.set_button(ge_down, gamepad, button, value);
        event.set_gamepad(gamepad_event, timestamp);
        app.dispatch_input_event(event);

        app.host.ongamepaddown( gamepad, button, value, timestamp );

    }

        /** manually dispatch a gamepad button up event through the system, delivered to the app handlers, internal and external */
    public function dispatch_gamepad_button_up_event( gamepad:Int, button:Int, value:Float, timestamp:Float ) {

        assert(gamepad_button_released.exists(gamepad), 'gamepad with id $gamepad not pre-inited? Is gamepad_init_count too low, or the gamepad id not sequential from 0?');
        assert(gamepad_button_down.exists(gamepad), 'gamepad with id $gamepad not pre-inited? Is gamepad_init_count too low, or the gamepad id not sequential from 0?');

            //flag it as released but unprocessed
        gamepad_button_released.get(gamepad).set(button, false);
            //flag it as down, because gamepadup removes it
        gamepad_button_down.get(gamepad).remove(button);

        gamepad_event.set_button(ge_up, gamepad, button, value);
        event.set_gamepad(gamepad_event, timestamp);
        app.dispatch_input_event(event);

        app.host.ongamepadup(gamepad, button, value, timestamp);

    }

        /** manually dispatch a gamepad device event through the system, delivered to the app handlers, internal and external */
    public function dispatch_gamepad_device_event( gamepad:Int, id:String, type:GamepadDeviceEventType, timestamp:Float ) {

        gamepad_event.set_device(gamepad, id, type);
        event.set_gamepad(gamepad_event, timestamp);
        app.dispatch_input_event(event);

        app.host.ongamepaddevice(gamepad, id, type, timestamp);

    }

//Interal API
 //
        /** Called when a system event is dispatched through the core */
    function onevent( _event:SystemEvent ) {

        if(_event.type == se_tick) {
            _update_keystate();
            _update_gamepadstate();
            _update_mousestate();
        }

    }


//internal
 //
        /** update mouse pressed/released/down states */
    function _update_mousestate() {

        var keys = mouse_button_pressed.iterableKeys;
        var len = keys.length;
        for(i in 0...len) tmp_int_array[i] = keys[i];
        for(i in 0...len){
            var _code = tmp_int_array[i];

            if(mouse_button_pressed.get(_code)){
                mouse_button_pressed.remove(_code);
            } else {
                mouse_button_pressed.set(_code, true);
            }

        } //each mouse_button_pressed

        keys = mouse_button_released.iterableKeys;
        len = keys.length;
        for(i in 0...len) tmp_int_array[i] = keys[i];
        for(i in 0...len){
            var _code = tmp_int_array[i];

            if(mouse_button_released.get(_code)){
                mouse_button_released.remove(_code);
            } else {
                mouse_button_released.set(_code, true);
            }

        } //each mouse_button_released

    }

        /** update gamepad pressed/released/down/axis states */
    function _update_gamepadstate() {

        for (i in 0...gamepad_button_pressed.values.length){
            var _gamepad_pressed = gamepad_button_pressed.values.get(i);
            if (_gamepad_pressed == null) continue;
            
            var keys = _gamepad_pressed.iterableKeys;
            var len = keys.length;
            for(j in 0...len) tmp_int_array[j] = keys[j];
            for (j in 0...len) {
                var _button = tmp_int_array[j];

                if(_gamepad_pressed.get(_button)){
                    _gamepad_pressed.remove(_button);
                } else {
                    _gamepad_pressed.set(_button, true);
                }

            } //each _gamepad_pressed
        } //each gamepad_button_pressed

        for (i in 0...gamepad_button_released.values.length){
            var _gamepad_released = gamepad_button_released.values.get(i);
            if (_gamepad_released == null) continue;

            var keys = _gamepad_released.iterableKeys;
            var len = keys.length;
            for(j in 0...len) tmp_int_array[j] = keys[j];
            for (j in 0...len) {
                var _button = tmp_int_array[j];

                if(_gamepad_released.get(_button)){
                    _gamepad_released.remove(_button);
                } else {
                    _gamepad_released.set(_button, true);
                }

            } //each _gamepad_released
        } //each gamepad_button_released

    }

        /** update key pressed/released/down states */
    function _update_keystate() {

            //remove any stale key pressed value
            //unless it wasn't alive for a full frame yet,
            //then flag it so that it may be
        var keys = key_code_pressed.iterableKeys;
        var len = keys.length;
        for(i in 0...len) tmp_int_array[i] = keys[i];
        for(i in 0...len){
            var _code = tmp_int_array[i];

            if(key_code_pressed.get(_code)){
                key_code_pressed.remove(_code);
            } else {
                key_code_pressed.set(_code, true);
            }

        } //each key_code_pressed

            //remove any stale key released value
            //unless it wasn't alive for a full frame yet,
            //then flag it so that it may be
        keys = key_code_released.iterableKeys;
        len = keys.length;
        for(i in 0...len) tmp_int_array[i] = keys[i];
        for(i in 0...len){
            var _code = tmp_int_array[i];

            if(key_code_released.get(_code)){
                key_code_released.remove(_code);
            } else {
                key_code_released.set(_code, true);
            }

        } //each key_code_released

    //scans

            //remove any stale key pressed value
            //unless it wasn't alive for a full frame yet,
            //then flag it so that it may be
        keys = scan_code_pressed.iterableKeys;
        len = keys.length;
        for(i in 0...len) tmp_int_array[i] = keys[i];
        for(i in 0...len){
            var _code = tmp_int_array[i];

            if(scan_code_pressed.get(_code)){
                scan_code_pressed.remove(_code);
            } else {
                scan_code_pressed.set(_code, true);
            }

        } //each scan_code_pressed

            //remove any stale key released value
            //unless it wasn't alive for a full frame yet,
            //then flag it so that it may be
        keys = scan_code_released.iterableKeys;
        len = keys.length;
        for(i in 0...len) tmp_int_array[i] = keys[i];
        for(i in 0...len){
            var _code = tmp_int_array[i];

            if(scan_code_released.get(_code)){
                scan_code_released.remove(_code);
            } else {
                scan_code_released.set(_code, true);
            }

        } //each scan_code_released

    }



        //this is the keycode based flags for keypressed/keyreleased/keydown
    var key_code_down : IntBoolMap;
    var key_code_pressed : IntBoolMap;
    var key_code_released : IntBoolMap;

        //this is the scancode based flags for scanpressed/scanreleased/scandown
    var scan_code_down : IntBoolMap;
    var scan_code_pressed : IntBoolMap;
    var scan_code_released : IntBoolMap;

        //this is the mouse button based flags for mousepressed/mousereleased/mousedown
    var mouse_button_down : IntBoolMap;
    var mouse_button_pressed : IntBoolMap;
    var mouse_button_released : IntBoolMap;

        //this is the gamepad button based flags for gamepadpressed/gamepadreleased/gamepaddown
    var gamepad_button_down : IntMap< IntBoolMap >;
    var gamepad_button_pressed : IntMap< IntBoolMap >;
    var gamepad_button_released : IntMap< IntBoolMap >;
    var gamepad_axis_values : IntMap< IntFloatMap >;

        //:todo: touch state maps and count
        //map of the touches currently down,
    @:noCompletion public var touch_count : Int = 0;
    @:noCompletion public var touches_down : IntBoolMap;


}


