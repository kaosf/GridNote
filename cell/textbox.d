module cell.textbox;

import derelict.sdl2.sdl;
import derelict.sdl2.ttf;
import cell.cell;
import text.text;
import std.string;
import misc.direct;

class TextBOX : CellBOX
{   // text の行数を Cellの高さに対応させてみる
    this(CellBOX replace){ 
        text = new Text();
        super(replace);
    }
    // this(TextBOX replace){
    //     text = new Text();
    //     super(replace);
    // }
    ~this(){ SDL_DestroyTexture(texture); }

    Text text;
    Cell text_offset;

    bool loaded_flg;
    // int cursor;
    int current_line;
    string font_name;
    char[] composition;
    int font_size;
    SDL_Color font_color;
    SDL_Texture* texture;
    invariant(){
        // assert(current_line <= text.num_of_lines);
    }
    Text exportText(){
        return text;
    }
    void insert_char(char c){
        import std.stdio;
        writefln("insert :%c",c);
        writefln("current_line :%d",current_line);
        writefln("position :%d",text.position);
        text.insert(current_line,c);
    }
    alias text.move_cursor!("cursor < right_edge_pos()",
            "++cursor;" )  move_cursorR; 
    alias text.move_cursor!("cursor != 0",
            "--cursor;" )  move_cursorL; 
    alias text.move_cursor!("lines > current_line",
            "++current_line;" )  move_cursorD; 
    alias text.move_cursor!("current_line != 0",
            "--current_line;" )  move_cursorU; 
    void set_cursor()(int pos){
        text.set_cursor(pos); // 
    }
}
