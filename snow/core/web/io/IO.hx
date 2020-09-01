package snow.core.web.io;

#if snow_web

import snow.types.Types;
import snow.api.buffers.Uint8Array;
import snow.api.Promise;
import snow.api.Debug.*;

using StringTools;

@:allow(snow.systems.io.IO)
class IO implements snow.modules.interfaces.IO {

    #if snow_web_use_electron_fs
    var tested_electron_availability:Bool = false;
    var electron:Dynamic = null;
    #end

    var app: snow.Snow;
    function new(_app:snow.Snow) app = _app;
    function shutdown() {}
    function onevent( _event:SystemEvent ) : Void {}

//Public API

    public function app_path() : String {

        return './';

    }

    public function app_path_prefs() : String {

        return './';

    }

    public function url_open( _url:String ) {

        if(_url != null && _url.length > 0) {
            js.Browser.window.open(_url, '_blank');
        }

    }

        /** Load bytes from the file path/url given.
            On web a request is sent for the data */
    public function data_load( _path:String, ?_options:IODataOptions ) : Promise {

        return new Promise(function(resolve,reject) {

            #if snow_web_use_electron_fs

            if (!tested_electron_availability) {
                tested_electron_availability = true;
                try {
                    electron = untyped __js__("require('electron')");
                }
                catch (e:Dynamic) {}
            }

            if (electron != null && !_path.startsWith('http://') && !_path.startsWith('https://')) {

                var fs = untyped __js__("{0}.remote.require('fs')", electron);
                var cwd = untyped __js__("{0}.remote.process.cwd()", electron);

                var _binary = true;

                if(_options != null) {
                    if(_options.binary != null) _binary = _options.binary;
                }

                try {
                    var result = fs.readFileSync(_path);

                    // Copy data and get rid of nodejs buffer
                    var data = new Uint8Array(result.length);
                    for (i in 0...result.length) {
                        data[i] = untyped __js__("{0}[{1}]", result, i);
                    }

                    resolve( data );
                }
                catch (e:Dynamic) {
                    reject(Error.error('failed to read file at path $_path: ' + e));
                }

            }
            else {

            #end

                    //defaults
                var _async = true;
                var _binary = true;

                if(_options != null) {
                    if(_options.binary != null) _binary = _options.binary;
                }

                var request = new js.html.XMLHttpRequest();
                    request.open("GET", _path, _async);

                if(_binary) {
                    request.overrideMimeType('text/plain; charset=x-user-defined');
                } else {
                    request.overrideMimeType('text/plain; charset=UTF-8');
                }

                    //only _async can set this type
                if(_async) {
                    request.responseType = js.html.XMLHttpRequestResponseType.ARRAYBUFFER;
                }

                request.onload = function(data) {

                    if(request.status == 200) {
                        resolve( new Uint8Array(request.response) );
                    } else {
                        reject(Error.error('request status was ${request.status} / ${request.statusText}'));
                    }

                }

                request.send();

            #if snow_web_use_electron_fs
            }
            #end

        });

    }

    public function data_save( _path:String, _data:Uint8Array, ?_options:IODataOptions ) : Bool {

        return false;

    }


        /** Returns the path where string_save operates.
            One targets where this is not a path, the path will be prefaced with `< >/`,
            i.e on web targets the path will be `<localstorage>/` followed by the ID. */
    public function string_save_path( ?_slot:Int = 0 ) : String {

        var _pref_path = '<localstorage>';
        var _slot_path = string_slot_id(_slot);
        var _path = haxe.io.Path.join([_pref_path, _slot_path]);

        return haxe.io.Path.normalize(_path);

    }

//Internal API

    inline function string_slot_id(_slot:Int = 0) {
        var _parts = snow.types.Config.app_ident.split('.');
        var _appname = _parts.pop();
        var _org = _parts.join('.');

        return '$_org/$_appname/${app.io.string_save_prefix}.$_slot';
    }

    inline function string_slot_destroy( ?_slot:Int = 0 ) : Bool {

        var storage = js.Browser.window.localStorage;
        if(storage == null) {
            log('localStorage isnt supported in this browser?!');
            return false;
        }

        var _id = string_slot_id(_slot);

        storage.removeItem(_id);

        return false;

    }

        //flush the string map to disk
    inline function string_slot_save( ?_slot:Int = 0, _contents:String ) : Bool {

        var storage = js.Browser.window.localStorage;
        if(storage == null) {
            log('localStorage isnt supported in this browser?!');
            return false;
        }

        var _id = string_slot_id(_slot);

        storage.setItem(_id, _contents);

        return true;

    }

        //get the string contents of this slot,
        //or null if not found/doesn't exist
    inline function string_slot_load( ?_slot:Int = 0 ) : String {

        var storage = js.Browser.window.localStorage;
        if(storage == null) {
            log('localStorage isnt supported in this browser?!');
            return null;
        }

        var _id = string_slot_id(_slot);

        return storage.getItem(_id);

    }

    inline function string_slot_encode( _string:String ) : String {
        return js.Browser.window.btoa(_string);
    }

    inline function string_slot_decode( _string:String ) : String {
        return js.Browser.window.atob(_string);
    }


}

#end //snow_web
