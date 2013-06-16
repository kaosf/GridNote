module manip;

import util.direct;
import util.color;
import cell.textbox;
import cell.cell;
import cell.table;
import cell.select;
import cell.contentbox;
import command.command;
import gui.pageview;

import gtk.IMMulticontext;
import gtk.IMContext;
import gtk.FileChooserDialog;

import std.array;
import std.stdio;
import std.string;
debug(manip) import std.stdio;

enum FocusMode{ normal,select,edit,point }

// Tableに対する操作
// CMDは指示を投げるだけってことをやるかってこと
// このコメントを消そうとするときに考える

// Table に関する操作
   // ここからCellBOXに対する操作も行う
   // 表示位置の移動ってここでやってしまおうか
   // 指示棒をここがもってるから
   // 指示棒自体はCell::SelectBOX
final class ManipTable{
private:
    BoxTable  _focused_table;
    CellContent _maniped_box;
    CellContent[] _old_state;
    PageView  _pv;
    SelectBOX _select;
    FocusMode _mode;

    Color  _selected_color;
    string _box_type;
    bool   _box_use_im;
    ManipTextBOX _manip_textbox;
public:
    this(BoxTable table,PageView p)
        out{
        assert(_focused_table);
        assert(_manip_textbox);
        assert(_select);
        assert(_pv);
        }
    body{
        _focused_table = table;
        _select = new SelectBOX(_focused_table);

        _manip_textbox = new ManipTextBOX(this);
        _pv =  p;
    }
    void move_focus(in Direct dir){
        immutable focus = _select.focus();
        immutable max_view = _pv.get_view_max();
        immutable min_view = _pv.get_view_min();
        if((focus.column <= min_view.column && dir == left)
        || (focus.row <= min_view.row && dir == up)
        || (focus.column >= max_view.column && dir==right )
        || (focus.row >= max_view.row && dir==down ))
        {
            debug(manip) writeln("focus ",focus);
            debug(manip) writeln("max ",max_view);

            _pv.move_view(dir);
            _select.move(dir);
        }
        else
            _select.move(dir);
        debug(manip) writefln("focus: %s",_select.focus);
    }
    CellContent get_target(){
        return _maniped_box;
    }
    void change_mode_select()
        in{
        assert(_mode != FocusMode.select);
        }
        out{
        assert(_mode == FocusMode.select);
        }
    body{
        _mode = FocusMode.select;
        _select.set_pivot();
    }
    @property auto targetbox(){
        switch(_box_type){
            case "cell.textbox.TextBOX":
                return cast(TextBOX)_maniped_box;
            default:
                return null;
        }
    }
    // 端点にfocusがあればexpand, そうでなくてもfocusは動く
    void expand_if_on_edge(in Direct dir){
        if(_select.is_on_edge(dir))
        {
            expand_select(dir);
        }
        move_focus(dir);
    }
    // moveとCMD単位で分離したかったが、
    // 初回の切り分けが複雑になるのでこうなった
    // 必要ならexpand_to_focus(no args)書いてそれをCMD化すればいい
    void expand_to_focus(in Direct dir)
        out{
        assert(_mode==FocusMode.select || _mode==FocusMode.edit);
        }
    body{
        if(_mode == FocusMode.normal)
        {
            change_mode_select();
        }
        move_focus(dir);
        _select.expand_to_focus();
    }
    void expand_select(in Direct dir)
        in{
        assert(_mode==FocusMode.select || _mode==FocusMode.edit);
        }
        out{
        assert(_mode==FocusMode.select || _mode==FocusMode.edit);
        }
    body{
        _mode = FocusMode.select;
        _select.expand(dir);
    }
    void delete_selected_area(){
        const select_min = _select.top_left;
        const select_max = _select.bottom_right;
        auto selected = _focused_table.get_contents(select_min,select_max);
        foreach(box; selected)
        {
            box[1].remove_from_table();
        }
    }
    void grab_selectbox(){
        auto target = _focused_table.get_content(_select.focus);
        _box_type = target[0];
        _maniped_box = target[1];
        if(_box_type == "cell.textbox.TextBOX")
            _box_use_im = true;
    }
    void move_selected(in Direct to){
        auto target = _focused_table.get_content(_select.focus)[1];
        immutable view_min = _pv.get_view_min();
        immutable view_max = _pv.get_view_max();
        if(target is null) return;
        else{
            if(target.top_left.row <= view_min.row && to == up)
            {   // viewを動かしたあとそれに合わせるためにmoveする
                // このrequire_moveは必ず通る
                _pv.move_view(to);
                target.require_move(to);
                    move_focus(to);
                if(!view_min.row)
                    _select.move(to.reverse);
            }
            else if(target.top_left.column <= view_min.column && to == left)
            {
                _pv.move_view(to);
                target.require_move(to);
                    move_focus(to);
                if(!view_min.column)
                     _select.move(to.reverse);
            }
            else if(target.bottom_right.row >= view_max.row && to == down)
            {   // 
                _pv.move_view(to);
                if(target.require_move(to))
                    move_focus(to);
            }
            else if(target.bottom_right.column >= view_max.column && to==right)
            {
                _pv.move_view(to);
                if(target.require_move(to))
                    move_focus(to);
            }
            else if(target.require_move(to)
                 ||(target.top_left.column == view_min.column && to == left)
                 ||(target.top_left.row == view_min.row && to == up))
               _select.move(to);
        }
    }
    void delete_selected(){
        auto target = _focused_table.get_content(_select.focus);
        if(target[1] is null) return;
        else{
            target[1].remove_from_table();
        }
    }
    void change_mode_normal()
        out{
        assert(_mode == FocusMode.normal);
        }
    body{
        debug(manip) writeln("return to normal start");
        _mode = FocusMode.normal;
        if(_maniped_box !is null)
        {   // _maniped_box.is_to_spoil == false なら削除されない
            _focused_table.try_remove(_maniped_box);
        }
        _select.selection_clear();
        _box_use_im = false;
        debug(manip) writeln("returned");
    }
    void change_mode_point(){
        change_mode_normal();
        _mode = FocusMode.point;
    }
    void change_mode_edit()
        out{
        assert(_mode == FocusMode.edit);
        }
    body{
        _mode = FocusMode.edit;
    }
    void create_TextBOX(){
        debug(manip) writeln("start_insert_normal_text");
        _mode = FocusMode.edit;
        if(_focused_table.has(_select.focus)) return;
        auto tb = _select.create_TextBOX();
        tb.set_box_default_color(_selected_color);

        _maniped_box = tb;
        _box_type = tb.toString();
        _box_use_im = true;
        debug(manip) writeln("type in: ",tb.toString());
        debug(manip) writeln("end");
    }
    void select_color(in Direct dir){
        _pv.guide_view.select_color(dir);
        _selected_color = get_selectedColor();
        if(_mode == FocusMode.edit)
            _maniped_box.set_color(_selected_color);
    }
    void select_color(in Color c){
        _selected_color = c;
    }
    const(Color) get_selectedColor(){
        return _pv.guide_view.get_selectedColor();
    }
    void create_CircleBOX(){
        debug(manip) writeln("@@@@ start create_ImageBOX @@@@");
        _mode = FocusMode.edit;
        if(_focused_table.has(_select.focus)) return;
        auto ib = _select.create_CircleCell(_selected_color,_pv);

        _maniped_box = ib;
        _box_type = ib.toString();
        _box_use_im = false;
        debug(manip) writeln("#### end create_ImageBOX ####");
    }
    void create_RectBOX(){
        debug(manip) writeln("@@@@ start create_ImageBOX @@@@");
        _mode = FocusMode.edit;
        if(_focused_table.has(_select.focus)) return;
        auto ib = _select.create_RectCell(_selected_color,_pv);

        _maniped_box = ib;
        _box_type = ib.toString();
        _box_use_im = false;
        debug(manip) writeln("#### end create_ImageBOX ####");
    }
    void im_commit_to_box(string str){
        debug(manip) writeln("send to box start with :",str);
        if(_mode!=FocusMode.edit)
        {   // 本当はこんな状態になってるのがおかしいわけで
            _pv.IM_FocusOut();
            return;
        }
        switch(_box_type){
           case "cell.textbox.TextBOX":
               _old_state ~= new TextBOX(_focused_table,cast(TextBOX)_maniped_box);
               _manip_textbox.with_commit(str,targetbox);
               return;
           default:
               return;
        }
    }
    void backspace(){
        debug(manip) writeln("back space start");
        _old_state ~= _maniped_box;
        switch(_box_type){
            case "cell.textbox.TextBOX":
                _manip_textbox.backspace(cast(TextBOX)_maniped_box);
                return;
            default:
                return;
        }
    }
    void text_feed(){
        auto tb = cast(TextBOX)_maniped_box;
        _old_state ~= new TextBOX(_focused_table,tb);
        if(_box_type == "cell.textbox.TextBOX")
        _manip_textbox.feed(tb);
    }
    void edit_textbox(){
        if(_box_type != "cell.textbox.TextBOX") 
            return;
        _old_state ~= _maniped_box;
        if(_box_type != "cell.textbox.TextBOX") return;
    }
    void undo(){
        if(!_old_state.empty())
        _maniped_box = _old_state[$-1];
    }
    import gtk.FileChooserDialog;
    import gtk.Window;
    private FileChooserDialog _file_chooser;
    private string _opened_file;
    string choose_save_file(){
        string file_name;
        if(!_file_chooser)
        {
            string[] a;
            ResponseType[] r;
            a ~= "Save on!";
            a ~= "Cancel";
            r ~= ResponseType.ACCEPT;
            r ~= ResponseType.CANCEL;
            scope win = new Window("saving");
            _file_chooser = new FileChooserDialog("File Selection", win, FileChooserAction.SAVE,a,r);
        }
        _file_chooser.setFileChooserAction(FileChooserAction.SAVE);
        auto response = _file_chooser.run();
        if(response == ResponseType.ACCEPT )
        {
            _opened_file = file_name = _file_chooser.getFilename();
        }else
            _opened_file = "";
        _file_chooser.hide();
        return file_name;
    }
    bool preserve(string file_name = ""){
        if(_opened_file) 
            file_name = _opened_file;
        else 
            file_name = choose_save_file();
        if(!file_name) 
            file_name = "tmp.dat";

        auto file = File(file_name,"w");
        if(!file.isOpen()) return false;
        auto all_ibs = _focused_table.get_imageBoxes();
        foreach(ib; all_ibs)
        {
            if(auto rect = cast(RectBOX)ib)
            {
                file.write(rect.get_data_expression);
            }
        }
        auto all_txt = _focused_table.get_textBoxes();
        foreach(tb; all_txt)
        {
            file.write(tb.get_dat());
        }
        return true;
    }
    string choose_open_file(){
        string file_name;
        if(!_file_chooser)
        {
            string[] a;
            ResponseType[] r;
            a ~= "Open!";
            a ~= "Cancel";
            r ~= ResponseType.ACCEPT;
            r ~= ResponseType.CANCEL;
            scope win = new Window("restore");
            _file_chooser = new FileChooserDialog("File Selection", win, FileChooserAction.OPEN,a,r);
        }
        _file_chooser.setFileChooserAction(FileChooserAction.OPEN);
        auto response = _file_chooser.run();
        if( response == ResponseType.ACCEPT )
        {
            _opened_file = file_name = _file_chooser.getFilename();
        }
        _file_chooser.hide();
        return file_name;
    }
    void restore(){
        string file_name;
        if(_opened_file)
            file_name = _opened_file;
        else 
            file_name = choose_open_file();

        _focused_table.clear();
        auto file = File(file_name,"r");

        string[][int] line_buf;
        int i;
        foreach(string l; lines(file))
        {   
            if(l[0] == '[')
                ++i;
            line_buf[i-1] ~= l;
        }
        foreach(l; line_buf)
        {
            switch(chomp(l[1])){
                case "RectBOX":
                    new RectBOX(_focused_table,_pv,l);
                    break;
                case "TextBOX":
                    new TextBOX(_focused_table,l);
                    break;
                default:
                    break;
            }
        }
    }
    const(SelectBOX) select()const{
        return _select;
    }
    FocusMode mode()const{
        return _mode;
    }
    final class ManipTextBOX {
        // ManipTable _manip_table;
        // IMMulticontext _imm;
        // 上2つ使ってないかもしれない
        // manip_table渡してしまったらどうして分離してるのかわからない
        this(ManipTable mt){
            // _manip_table = mt;
        }
        // void move_caret(TextBOX box, in Direct dir){
        //     final switch(dir){
        //         case right:
        //             box.move_caretR(); return;
        //             return;
        //         case left:
        //             box.move_caretL(); return;
        //             return;
        //         case up:
        //             box.move_caretU(); return;
        //             return;
        //         case down:
        //             box.move_caretD(); return;
        //             return;
        //     }
        //     assert(0);
        // }
        void append(TextBOX box,string str){
            debug(manip) writeln("text insert strat");
            box.append(str);
            debug(manip) writeln("end");
        }
        void with_commit(string str,TextBOX box){
            debug(manip) writeln("with commit text");
            append(box,str);
        }
        void backspace(TextBOX box){
            box.backspace();
        }
        void feed(TextBOX box){
            box.expand_with_text_feed();
        }
        void set_foreground_color(TextBOX box,in Color c){
            box.set_foreground_color(c);
        }
        void set_color(TextBOX box,in Color c){
            box.set_foreground_color(c);
        }
    }
}


