package snow.core.web.assets;

#if snow_web

import snow.systems.assets.Asset.AssetImage;
import snow.systems.assets.Assets;
import snow.types.Types;
import snow.api.Debug.*;
import snow.api.buffers.*;
import snow.api.Promise;

import snow.core.web.assets.tga.TGA;
import snow.core.web.assets.psd.PSD;

@:allow(snow.systems.assets.Assets)
class Assets implements snow.modules.interfaces.Assets {

    #if snow_web_use_electron_pngjs
    var tested_electron_pngjs_availability:Bool = false;
    var electron:Dynamic = null;
    var pngjs:Dynamic = null;
    #end

//module interface

    var app: snow.Snow;
    function new( _app:snow.Snow ) app = _app;
    function onevent(event:SystemEvent):Void {}
    function shutdown() {}

//Public API

    //Images

        public function image_info_from_load( _id:String, ?_components:Int = 4 ) : Promise {

            return app.io.data_flow(_id, AssetImage.processor);

        }

            /** Create an image info (padded to POT) from a given Canvas or Image element. */
        public function image_info_from_element( _id:String, _elem ) : ImageData {

            var width_pot = nearest_power_of_two(_elem.width);
            var height_pot = nearest_power_of_two(_elem.height);
            var image_bytes = POT_bytes_from_element(_elem.width, _elem.height, width_pot, height_pot, cast _elem);

            var info = new ImageData(app, {
                id : _id,
                bpp : 4,
                width : _elem.width,
                height : _elem.height,
                width_actual : width_pot,
                height_actual : height_pot,
                bpp_source : 4,
                pixels : image_bytes
            });

            image_bytes = null;

            return info;

        }

        #if snow_web_use_electron_pngjs

            /** Create an image info (padded to POT) from a given Canvas or Image element. */
        public function image_info_from_pngjs_info( _id:String, _pngjs_info:Dynamic ) : ImageData {

            var width_pot = nearest_power_of_two(_pngjs_info.width);
            var height_pot = nearest_power_of_two(_pngjs_info.height);

            // Copy data and get rid of nodejs buffer
            var buffer_data = _pngjs_info.data;
            var pngjs_data = new Uint8Array(buffer_data.length);
            for (i in 0...buffer_data.length) {
                pngjs_data[i] = untyped __js__("{0}[{1}]", buffer_data, i);
            }

            var image_bytes = POT_bytes_from_pixels(_pngjs_info.width, _pngjs_info.height, width_pot, height_pot, pngjs_data);

            var info = new ImageData(app, {
                id : _id,
                bpp : 4,
                width : _pngjs_info.width,
                height : _pngjs_info.height,
                width_actual : width_pot,
                height_actual : height_pot,
                bpp_source : 4,
                pixels : image_bytes
            });

            image_bytes = null;
            buffer_data = null;

            return info;

        }

        #end

            /** Create an image info from raw (already decoded) image pixels */
        public function image_info_from_pixels(_id:String, _width:Int, _height:Int, _pixels:Uint8Array, ?_bpp:Int=4) : ImageData {

            var info = new ImageData(app, {
                id : _id,
                bpp : 4,
                width : _width,
                height : _height,
                width_actual : _width,
                height_actual : _height,
                bpp_source : 4,
                pixels : _pixels,
            });

            return info;
        }

            /** Create an image info (padded to POT) from bytes. Promises an ImageData. */
        public function image_info_from_bytes( _id:String, _bytes:Uint8Array, ?_components:Int = 4 ) : Promise {

            assertnull(_id);
            assertnull(_bytes);
            assert(_bytes.length != 0);

            var ext = haxe.io.Path.extension(_id);

            #if snow_web_tga
                if(ext == 'tga') return Promise.resolve(image_info_from_bytes_tga(_id, _bytes));
            #end

            #if snow_web_psd
                if(ext == 'psd') return Promise.resolve(image_info_from_bytes_psd(_id , _bytes));
            #end

            #if snow_web_use_electron_pngjs
            if (!tested_electron_pngjs_availability) {
                tested_electron_pngjs_availability = true;
                try {
                    electron = untyped __js__("require('electron')");
                    pngjs = untyped __js__("{0}.remote.require('pngjs')", electron);
                }
                catch (e:Dynamic) {}
            }

            if (pngjs != null && ext == 'png') {
                return new Promise(function(resolve, reject) {

                    try {
                        var Buffer = untyped __js__("{0}.remote.require('buffer').Buffer", electron);
                        var pngjs_info = pngjs.PNG.sync.read(Buffer.from(_bytes));

                        resolve(image_info_from_pngjs_info(_id, pngjs_info));
                    }
                    catch (e:Dynamic) {
                        reject(Error.error('failed to decode png: $_id ; $e'));
                    }

                });
            }
            #end

            return new Promise(function(resolve, reject) {

                    //convert to a binary string
                var str = '', i = 0, len = _bytes.length;
                while(i < len) str += String.fromCharCode(_bytes[i++] & 0xff);

                var b64 = js.Browser.window.btoa(str);
                var src = 'data:image/$ext;base64,$b64';

                    //convert to an image element
                var _img = new js.html.Image();

                _img.onload = function(_) {
                    var info = image_info_from_element(_id, _img);
                    resolve(info);
                }

                _img.onerror = function(e) {
                    reject(Error.error('failed to load image from bytes, on error: $e'));
                }

                _img.src = src;

            }); //promise

        }

//Internal converters

    #if snow_web_psd

        /** Return an image info from the bytes of a PSD image */
        function image_info_from_bytes_psd( _id:String, _bytes:Uint8Array ) {

            var psd = new PSD(_bytes);
                psd.parse();

            var _width = untyped psd.header.width;
            var _height = untyped psd.header.height;
            var _pixels = new Uint8Array(untyped psd.image.pixelData);

            return image_info_from_pixels(_id, _width, _height, _pixels);

        }

    #end //snow_web_psd

    #if snow_web_tga

        /** Return an image info from the bytes of a tga image */
        function image_info_from_bytes_tga( _id:String, _bytes:Uint8Array ) {

            var image = new TGA();
                image.load( _bytes );

            return image_info_from_element(_id, image.getCanvas());

        }

    #end //snow_web_tga

        /** Return a POT array of bytes from raw image pixels */
    function POT_bytes_from_pixels(_width:Int, _height:Int, _width_pot:Int, _height_pot:Int, _source:Uint8Array) : Uint8Array {

        var tmp_canvas = js.Browser.document.createCanvasElement();

            tmp_canvas.width = _width_pot;
            tmp_canvas.height = _height_pot;

        var tmp_context = tmp_canvas.getContext2d();

            tmp_context.clearRect( 0, 0, tmp_canvas.width, tmp_canvas.height );

        var image_bytes = null;
        var _pixels = new js.html.Uint8ClampedArray(_source.buffer);
        var _imgdata = tmp_context.createImageData( _width, _height );
            _imgdata.data.set(_pixels);

        try {

                //store the data in it first
            tmp_context.putImageData( _imgdata, 0, 0 );
                //then bring out the full size
            image_bytes = tmp_context.getImageData( 0, 0, tmp_canvas.width, tmp_canvas.height );

        } catch(e:Dynamic) {

            var tips = '- textures served from file:/// throw security errors\n';
                tips += '- textures served over http:// work for cross origin byte requests';

            log(tips);
            throw e;

        }

            //cleanup
        tmp_canvas = null; 
        tmp_context = null;
        _imgdata = null;

        return Uint8Array.fromView(image_bytes.data);
    
    }

        /** Return a POT array of bytes from an image/canvas element */
    function POT_bytes_from_element(_width:Int, _height:Int, _width_pot:Int, _height_pot:Int, _source:js.html.Element) : Uint8Array {

        var tmp_canvas = js.Browser.document.createCanvasElement();

            tmp_canvas.width = _width_pot;
            tmp_canvas.height = _height_pot;

        var tmp_context = tmp_canvas.getContext2d();

            tmp_context.clearRect( 0,0, tmp_canvas.width, tmp_canvas.height );
            tmp_context.drawImage( cast _source, 0, 0, _width, _height );

        var image_bytes = null;

        try {

            image_bytes = tmp_context.getImageData( 0, 0, tmp_canvas.width, tmp_canvas.height );

        } catch(e:Dynamic) {

            var tips = '- textures served from file:/// throw security errors\n';
                tips += '- textures served over http:// work for cross origin byte requests';

            log(tips);
            throw e;

        }

            //cleanup
        tmp_canvas = null; tmp_context = null;

        return Uint8Array.fromView(image_bytes.data);

    }


    //Internal helpers
        static var POT = true;

        function nearest_power_of_two(_value:Int) {

            if(!POT) return _value;

            _value--;

            _value |= _value >> 1;
            _value |= _value >> 2;
            _value |= _value >> 4;
            _value |= _value >> 8;
            _value |= _value >> 16;

            _value++;

            return _value;

        }

}

#end //snow_web
