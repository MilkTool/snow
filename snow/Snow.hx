package snow;

import snow.runtime.Runtime;
import snow.api.Debug.*;
import snow.api.Timer;
import snow.api.Promise;
import snow.api.buffers.Uint8Array;
import snow.types.Types;

import snow.system.io.IO;
import snow.system.input.Input;
import snow.system.assets.Assets;
import snow.system.audio.Audio;

class Snow {

    //public

            /** The host application */
        public var host : App;
            /** The application configuration specifics (like window, runtime, and asset lists) */
        public var config : snow.types.Types.AppConfig;
            /** Whether or not we are frozen, ignoring events i.e backgrounded/paused */
        public var freeze (default,set) : Bool = false;

            /** The current timestamp */
        public var time (get,never) : Float;
            /** Generate a unique ID to use */
        public var uniqueid (get,never) : String;
            /** A static access to the timestamp for convenience */
        public static var timestamp (get, never) : Float;

    //systems

            /** The runtime module */
        public static var runtime : Runtime;
            /** The io system */
        public var io : IO;
            /** The input system */
        public var input : Input;
            /** The audio system */
        public var audio : Audio;
            /** The asset system */
        public var assets : Assets;

    //state

            /** The platform identifier, a string,
                but uses `snow.types.Types.Platform` abstract enum internally */
        public var platform : String = 'unknown';
            /** The os identifier, a string,
                but uses `snow.types.Types.OS` abstract enum internally */
        public var os : String;
            /** A debug flag for convenience, true if the app was built with the haxe -debug flag or define */
        public var debug : Bool = #if debug true #else false #end;

            /** Set if shut down has commenced */
        public var shutting_down : Bool = false;
            /** Set if shut dow has completed  */
        public var has_shutdown : Bool = false;

    //api

        public function new(_host : App) {

            log('app / init / debug:$debug');
            log('app / ident: ' + snow.Set.app_ident);
            log('app / config: ' + snow.Set.app_config);

            if(snow.api.Debug.get_level() > 1) {
                log('log / level to ${snow.api.Debug.get_level()}' );
                log('log / filter : ${snow.api.Debug.get_filter()}');
                log('log / exclude : ${snow.api.Debug.get_exclude()}');
            }

            host = _host;
            host.app = this;
            config = default_config();

            log('app / assets / ${snow.Set.module_assets}');
            log('app / audio / ${snow.Set.module_audio}');
            log('app / input / ${snow.Set.module_input}');
            log('app / io / ${snow.Set.module_io}');
            log('app / window / ${snow.Set.module_window}');

            io = new IO(this);
            input = new Input(this);
            audio = new Audio(this);
            assets = new Assets(this);

            log('app / runtime / new ${snow.Set.app_runtime}');

            runtime = new snow.Set.HostRuntime(this);

            assertnull(os, 'init - Runtime didn\'t set the app.os value!');
            assertnull(platform, 'init - Runtime didn\'t set the app.platform value!');

            log('app / os:$os / platform:$platform / init / $time');
            onevent({ type:init });

            step();

            log('app / ready / $time');
            onevent({ type:ready });

            step();

            log('app / runtime / ${runtime.name} / run');
            runtime.run();

            if(!(has_shutdown || shutting_down)) {
                shutdown();
            }

        } //new

            /** Shutdown the engine and quit */
        public function shutdown() {

            assert(shutting_down == false, 'snow - calling shutdown more than once is disallowed');
            assert(has_shutdown == false, 'snow - calling shutdown more than once is disallowed');

            shutting_down = true;

            host.ondestroy();

            onevent({ type:SystemEventType.shutdown });

            io.shutdown();
            audio.shutdown();
            assets.shutdown();
            input.shutdown();
            
            runtime.shutdown();

            has_shutdown = true;

        } //shutdown

    //events

            /** Handles snow system events, typically emitted via the runtime and modules. 
                Dispatch events manually using the `dispatch_*` calls. */
        public function onevent(_event:SystemEvent) {

            // if( _event.type != SystemEventType.update ) {
                log('event / system event / ${_event.type}');
            // }

            io.onevent( _event );
            audio.onevent( _event );
            input.onevent( _event );
            host.onevent( _event );

            switch(_event.type) {

                case ready: on_ready_event();
                case update: on_update_event();
                case quit, app_terminating: shutdown();
                case shutdown: log('Goodbye.');
                case _:

            } //switch _event.type

        } //onevent

            /** Call a function at the start of the next frame,
                useful for async calls in a sync context, allowing the sync function to return safely before the onload is fired. */
        inline
        public static function next( func: Void->Void ) {

            if(func != null) next_queue.push(func);

        } //next

            /** Call a function at the end of the current frame */
        inline
        public static function defer( func: Void->Void ) {

            if(func != null) defer_queue.push(func);

        } //defer

    //internal

        inline function get_time() : Float return runtime.timestamp();
        inline function get_uniqueid() : String return make_uniqueid();
        static inline function get_timestamp() : Float return runtime.timestamp();

    //internal event handlers

        var was_ready = false;
        inline function on_ready_event() {

            assert(was_ready == false, 'snow; the ready event should not be fired repeatedly');
            was_ready = true;

            setup_configs().then(function(_){

                _debug('init / setup default configs : ok');

                // setup_default_window();

                _debug('init / queing host ready');

                host.ready();

            }).error(function(e) {

                throw Error.init('snow / cannot recover from error: $e');

            });

            step();

        } //on_ready_event
        
        inline function on_update_event() {

            if(freeze) return;

                //first update timers
            Timer.update();

                //handle promise executions
            snow.api.Promise.Promises.step();

                //handle the events
            cycle_next_queue();

                //handle any internal pre updates
            host.ontickstart();

                //handle any internal updates
            // host.on_internal_update();

                //handle any internal render updates
            // host.on_internal_render();

                //let the system have some time
            #if snow_native
                Sys.sleep(0);
            #end

                //handle any internal post updates
            host.ontickend();

            cycle_defer_queue();

        } //on_update_event

    //setup and boot
     
        function setup_configs() {

                //blank/null config path means don't try to load it
            if(snow.Set.app_config == null || snow.Set.app_config == '') {

                setup_host_config();

                return Promise.resolve();

            } //blank config

            return new Promise(function(resolve, reject) {

                _debug('config / fetching runtime config');

                default_runtime_config().then(function(_runtime_conf:Dynamic) {

                    config.runtime = _runtime_conf;

                }).error(function(error){

                    throw Error.init('config / failed / default runtime config JSON failed to parse. Cannot recover. $error');

                }).then(function(){

                    setup_host_config();
                    resolve();

                });

            }); //promise

        } //setup_configs

        inline function setup_host_config() {

            _debug('config / fetching user config');

            config = host.config( config );

        } //setup_host_config

            /** handles the default method of parsing a runtime config json,
                To change this behavior override `get_runtime_config`. This is called by default in get_runtime_config. */
        function default_runtime_config() : Promise {

            _debug('config / setting up default runtime config');

                //for the default config, we only reject if there is a json parse error
            return new Promise(function(resolve, reject) {

                var load = io.data_flow(assets.path(snow.Set.app_config), AssetJSON.processor);

                    load.then(resolve).error(function(error:Error) {
                        switch(error) {
                            case Error.parse(val):
                                reject(error);
                            case _:
                                log('config / runtime config will be null! / $error');
                                resolve(null);
                        }
                    });

            }); //promise

        } //default_runtime_config

        function default_config() : AppConfig {

            return {
                has_window : true,
                runtime : {},
                window : default_window_config(),
                render : default_render_config(),
                web : {
                    no_context_menu : true,
                    prevent_default_keys : [
                        Key.left, Key.right, Key.up, Key.down,
                        Key.backspace, Key.tab, Key.delete
                    ],
                    prevent_default_mouse_wheel : true,
                    true_fullscreen : false
                },
                native : {
                    audio_buffer_length : 176400,
                    audio_buffer_count : 4
                }
            }

        } //default_config

        /** Returns a default configured render config */
        function default_render_config() : RenderConfig {

            _debug('config / fetching default render config');

            return {
                depth : false,
                stencil : false,
                antialiasing : 0,
                red_bits : 8,
                green_bits : 8,
                blue_bits : 8,
                alpha_bits : 8,
                depth_bits : 0,
                stencil_bits : 0,
                opengl : {
                    minor:0, major:0,
                    profile:OpenGLProfile.compatibility
                }
            };

        } //default_render_config

            /** Returns a default configured window config */
        function default_window_config() : WindowConfig {

            _debug('config / fetching default window config');

            var conf : WindowConfig = {
                fullscreen_desktop  : true,
                fullscreen          : false,
                borderless          : false,
                resizable           : true,
                x                   : 0x1FFF0000,
                y                   : 0x1FFF0000,
                width               : 960,
                height              : 640,
                title               : 'snow app'
            };

                #if mobile
                    conf.fullscreen = true;
                    conf.borderless = true;
                #end //mobile

            return conf;

        } //default_window_config

    //properties

        function set_freeze( _freeze:Bool ) {

            freeze = _freeze;

            //:todo: system pause event
            // if(_freeze) {
            //     audio.suspend();
            // } else {
            //     audio.resume();
            // }

            return freeze;

        } //set_freeze

    //step

        inline function step() {

            snow.api.Promise.Promises.step();

            while(next_queue.length > 0) {
                cycle_next_queue();
            }

            while(defer_queue.length > 0) {
                cycle_defer_queue();
            }

        } //step

    //callbacks
    
        static var next_queue : Array<Void->Void> = [];
        static var defer_queue : Array<Void->Void> = [];

        inline function cycle_next_queue() {

            var count = next_queue.length;
            var i = 0;
            while(i < count) {
                (next_queue.shift())();
                ++i;
            }

        } //cycle_next_queue

        inline function cycle_defer_queue() {

            var count = defer_queue.length;
            var i = 0;
            while(i < count) {
                (defer_queue.shift())();
                ++i;
            }

        } //cycle_next_queue

    //helpers

        function make_uniqueid(?val:Int) : String {

            // http://www.anotherchris.net/csharp/friendly-unique-id-generation-part-2/#base62

            if(val == null) {
                #if neko val = Std.random(0x3FFFFFFF);
                #else val = Std.random(0x7fffffff);
                #end
            }

            inline function to_char(value:Int) {
                if (value > 9) {
                    var ascii = (65 + (value - 10));
                    if (ascii > 90) ascii += 6;
                    return String.fromCharCode(ascii);
                } else return Std.string(value).charAt(0);
            } //to_char

            var r = Std.int(val % 62);
            var q = Std.int(val / 62);

            if (q > 0) return make_uniqueid(q) + to_char(r);

            return Std.string(to_char(r));

        } //make_uniqueid

        inline function typename(t:Dynamic) {

            return Type.getClassName(Type.getClass(t));

        } //typename

} //Snow
