package snow.modules.sdl;

import sdl.SDL;

import snow.api.Debug.*;
import snow.api.buffers.Uint8Array;
import snow.api.buffers.ArrayBufferView;
import snow.core.native.io.IO.FileSeek;
import snow.types.Types.FileHandle;

typedef FileHandle = sdl.RWops;

class IO extends snow.core.native.io.IO {

    override public function app_path() : String {

        var _path = SDL.getBasePath();
        if(_path == null) _path = '';

        return _path;

    }

    override public function app_path_prefs() {

        var _parts = snow.types.Config.app_ident.split('.');
        var _appname = _parts.pop();
        var _org = _parts.join('.');

        return SDL.getPrefPath(_org, _appname);
    
    }

//File

    override public function file_handle(_path:String, ?_mode:String="rb") : FileHandle {

        return SDL.RWFromFile(_path, _mode);

    }

    override public function file_handle_from_mem(mem:ArrayBufferView, size:Int) : FileHandle {

        return SDL.RWFromMem(mem.buffer, size);

    }

    override public function file_read(file:FileHandle , dest:ArrayBufferView, size:Int, maxnum:Int) : Int {

        assertnull(file);

        return SDL.RWread(file, dest.buffer, size, maxnum);

    }

    override public function file_write(file:FileHandle, src:ArrayBufferView, size:Int, num:Int) : Int {

        assertnull(file);

        return SDL.RWwrite(file, src.buffer, size, num);

    }

    override public function file_seek(file:FileHandle, offset:Int, whence:Int) : Int {
        
        assertnull(file);

        return SDL.RWseek(file, offset, whence);

    }

    override public function file_tell(file:FileHandle) : Int {

        assertnull(file);

        return SDL.RWtell(file);

    }

    override public function file_close(file:FileHandle) : Int {

        assertnull(file);

        return SDL.RWclose(file);

    }


}
