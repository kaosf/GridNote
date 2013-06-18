module cell.textbox;

import cell.cell;
import cell.table;
import cell.contentbox;
public import text.text;
import text.tag;
import std.string;
import std.utf;
import std.conv;
import util.direct;
import shape.shape;
debug(cell) import std.stdio;
import std.stdio;

import pango.PgCairo;
import pango.PgLayout;
import pango.PgFontDescription;
import pango.PgAttribute;
import pango.PgAttributeList;

// Text自体をTableに取り付けるためにBOX領域を管理する
final class TextBOX : ContentBOX{  
private:
    Text _text;
    int _cursor_pos; // 描画側（IM)が教えるために使う

    string _box_fontfamly = "Sans";
    string _box_style = "Normal";
    ubyte  _box_font_size;
    Color _box_foreground = black;

    string desc_str(){
        _box_font_size = cast(ubyte)_table.grid_size / 2 ;
        return _box_fontfamly~' '~_box_style~' '~to!string(_box_font_size);
    }
public:
    this(BoxTable table){ 
        super(table);
    }
    this(BoxTable table,in Cell tl,in int w,in int h){
        super(table,tl,w,h);
    }
    this(BoxTable table,TextBOX tb){
        _text = tb._text;
        _cursor_pos = tb.cursor_pos;
        _box_foreground = tb._box_foreground;

        super(table,tb);
    }
    import std.ascii;
    this(BoxTable table,string[] data){
        super(table);
        auto pos = std.string.split(data[0],",");
        int[] pos_num;
        foreach(numstr; pos)
        {
            string num;
            foreach(numc; numstr)
            {
                if(isDigit(numc))
                    num ~= numc;
            }
            pos_num ~= to!int(num);
            writeln(pos_num);
        }

        writeln(pos);
        (require_create_in(Cell(pos_num[0],pos_num[1])));
        writeln(data[3]);
        auto desc = std.string.split(data[2]," ");
        writeln(desc);
        _box_fontfamly = chomp(desc[0]);
        _box_style = chomp(desc[1]);
        _box_font_size = to!ubyte(chomp(desc[2]));
        _box_foreground = Color(chomp(data[3]));
        _text = Text(data);
        if(_text.numof_lines > 1)
        require_expand(down,_text.numof_lines - 1);
    }        

    override bool require_create_in(in Cell c)
    {
        return _table.try_create_in!(TextBOX)(this,c);
    }
    void set_box_default_color(in Color c){
        _box_foreground = c;
    }
    void set_foreground_color(in Color c){
        if(_text.empty)
            _box_foreground = c;
        else
            _text.set_foreground(c);
    }
    override void set_color(in Color c){
        set_foreground_color(c);
    }
    void set_heading(ubyte size)
        in{
        assert(size >= 0);
        assert(size <= 6);
        }
    body{
    }
    void set_font_bigger()
    {
    }
    void append(string s){
        foreach(dchar c; s)
        {
            _text.append(c);
            if(c == '\n') // 入力中は作動せず(改行文字は直接渡されない)、存在するstringを渡した時を想定している
                expand_with_text_feed();
        }
    }
    void backspace(){
        if(!_text.backspace()) // 行始でfalse
            require_remove(down);
    }
    // 現状caretは改行時のみの使用になってる
    // Text::TextPointをcaretとして扱う実装仕様にする
    bool expand_with_text_feed(){
        if(require_expand(down))
        {
            _text.line_feed();
            return true;
        }else 
            return false;
    }
//     void set_caret()(in int pos){
//         _text.set_caret(pos); // 
//     }
    string markup_string(){
        if(_text.empty) return null;
        SpanTag box_desc;
        box_desc.font_desc(desc_str());
        box_desc.foreground(_box_foreground);
        auto tmp =  box_desc.tagging(_text.markup_string());
        return tmp;
    }
    // 操作が終わった時にTableから取り除くべきか
    // super.is_to_spoil()は強制削除のためにはかます必要がある
    override bool is_to_spoil()const{
        return super.is_to_spoil() || _text.empty();
    }
    Text getText(){
        return _text;
    }
    void set_cursor_pos(in int p){
        _cursor_pos = p;
    }
    @property int cursor_pos()const{
        return _text.current_pos;
    }
    @property int cursor_line()const{
        return _text.current_line;
    }
    @property int numof_lines()const{
        return _text.numof_lines;
    }
    @property Color default_foreground()const{
        return _box_foreground;
    }
    @property Color current_foreground()const{
        auto text_status = _text.current_foreground();
        if(text_status[0])
            return text_status[1];
        else 
            return default_foreground();
    }
    @property PgFontDescription font_desc(){
        return PgFontDescription.fromString(desc_str());
    }
    ubyte current_fontsize()const{
        const text_setting = _text.current_fontsize;
        return text_setting?
            text_setting : _box_font_size; 
    }
    int get_caret()const{
        return _text.caret;
    }
    string dat(in Cell offset=Cell(0,0)){
        string result ="[";
        writeln(top_left());
        result ~= to!string(top_left()-offset) ~',';
        result ~= to!string(numof_row) ~ ',';
        result ~= to!string(numof_row) ~ "]\n";
        result ~= "TextBOX\n";
        result ~= desc_str ~ '\n';
        result ~= _box_foreground.hex_str ~'\n';
        result ~= _text.dat();
        writeln(result);
        return result;
    }

}
