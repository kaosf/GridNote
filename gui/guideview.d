module gui.guideview;

debug(gui) import std.stdio;
import gui.tableview;
import std.string;
import std.array;
import env;
import cell.cell;
import cell.table;
import cell.refer;
import cell.textbox;
import text.text;
import util.direct;
import std.algorithm;
import gui.textbox;
import shape.shape;
import shape.drawer;

import command.command;

import gtkc.gdktypes;
import gtk.MainWindow;
import gtk.Widget;
import gtk.IMContext;

import gtk.EventBox;
import gtk.ImageMenuItem;
import gtk.AccelGroup;

import gdk.Event;

import gtk.DrawingArea;
import gtk.Menu;
import cairo.Surface;
import cairo.Context;

import cell.cell;
import cell.contentbox;
import cell.textbox;
import cell.imagebox;

import manip;

// BOXの移動操作を想定していない場合、
// Tableに存在していることが描画条件で、
// Content内部Cell保有状態全体をTableに登録する必要はない
// TableのCell空間は単一の要素しか入れないので、
// 共有したいなら、他のTableを用意するか、登録するCellをずらすか

final class GuideView : DrawingArea,TableView{
    private:
        int _gridSpace = 16;
        GtkAllocation _holding; // この2つの表すのは同じもの
        Rect _holding_area;  // 内部処理はこちらを使う

        BoxTable _table;    // 描画すべき個々のアイテムに対する
        BoxTable _selector_table; // selectorが動いたときの表示用
        TextBOX _mode_indicator;
        TextBOX _tag_view;

        RenderTextBOX _render_text;

        bool onButtonPress(Event event, Widget widget)
        {
            if( event.type == EventType.BUTTON_PRESS )
            {
                GdkEventButton* buttonEvent = event.button;

                if( buttonEvent.button == 3)
                {
                    return true;
                }
            }
            return false;
        }
        void set_holding_area()
            in{
            assert(_holding_area);
            }
            out{
            assert(_holding_area.w > 0);
            assert(_holding_area.h > 0);
            }
        body{
            getAllocation(_holding);
            _holding_area.set_by(_holding);

            immutable Min= Cell(15,8);
            immutable Max= Cell(35,10);
            const min_pos = get_pos(Min);
            const max_pos = get_pos(Max);

            if(_holding_area.w < min_pos[0])
                setSizeRequest(cast(int)min_pos[0],cast(int)min_pos[1]);
            else if(_holding_area.h > max_pos[0])
                setSizeRequest(cast(int)max_pos[0],cast(int)max_pos[1]);

            _holding_area.set_by(_holding);
        }
        RectBOX _back_color;
        Color _back_color_color = Color(darkgray,148);
        Color _down_accent = Color(moccasin,48);
        void backDesign(Context cr){
            _back_color.set_color(_back_color_color);
            _back_color.fill(cr);

            // shadow というか縦線
            cr.setLineWidth(2);
            cr.moveTo(_holding_area.w-2,0);
            cr.lineTo(_holding_area.w-2,_holding_area.h);
            cr.set_color(Color(gray,128));
            cr.stroke();

            _color_box_back.fill(cr);
        }
        void set_tag_text(){
            _tag_view = new TextBOX(_table);
            _tag_view.require_create_in(Cell(max_row*5/8,0));
        }

        void renderColorBox(Context cr){
            _selected_color_box.set_color(_selected_color);
            if(_selected_color in _color_box) {
                _selected_color_box.fill(cr);
                _color_box[_selected_color].set_width(6);        
                _color_box[_selected_color].stroke(cr);       
            }
            foreach(b; _color_box)
                b.fill(cr);
        }
        bool draw_callback(Context cr,Widget widget){
            if(!_c_cnt) return false;
            backDesign(cr);
            renderColorBox(cr);
            _renderDebug(cr);
            cr.resetClip(); // end of rendering
            return true;
        }
        void when_sizeallocated(GdkRectangle* n,Widget w){
            set_holding_area();
            reset_color_box();
            auto start_row = max_row()/2;
            _selected_color_box.hold_tl(Cell(start_row-3,1),2,2);
            _selected_color_box.set_drawer();
            _color_selector.reshape();
            _debug_msg.hold_tl(Cell(0,0),4,max_col()+1);

            _back_color.hold_tl(Cell(0,0),max_row()+1,max_col()+1);
            _back_color.set_drawer();

        }
        CircleBOX[Color] _color_box;
        Color[int] _color_priority;
        int[Color] _priority_color;
        RectBOX _selected_color_box;
        RectDrawer _color_back;
        RectBOX _color_box_back;
        ColorSelector _color_selector;

    class ColorSelector{
    private:
        Cell _focus;
        int _focus_priority;
        Cell calc_Cell_pos(in int priority){
            const turn_col = _colorbox_turn_column;
            auto col = priority % turn_col;
            auto row = (priority-1) / turn_col;
            return _colorbox_start_pos + Cell(row,col);
        }
        CircleBOX _drwer;
    public:
        this(){
            _focus = _colorbox_start_pos;
            _drwer = new CircleBOX(_selector_table,this.outer);
            _drwer.require_create_in(_focus);
            _drwer.set_drawer();
            _debug_msg = new TextBOX(_table);
            _debug_msg.require_hold(Cell(0,0),5,max_col());
        }
        void move(in Direct dir){
            int pre_calc_diff;
            const exist_priority_limit = _color_priority.keys.sort[$-1];
            if(dir.is_vertical)
                pre_calc_diff = _colorbox_turn_column;
            else
                pre_calc_diff = 1;
            if(dir.is_negative)
                pre_calc_diff = -pre_calc_diff;

            auto pre_result = _focus_priority + pre_calc_diff;
            if(pre_result < 0 || pre_result > exist_priority_limit )
                return;
            else {
                _focus_priority = pre_result;
                _focus = calc_Cell_pos(_focus_priority);
                _drwer.require_create_in(_focus);
                _selected_color = color;
                this.outer.queueDraw();
            }
        }
        void reshape(){
            _focus = calc_Cell_pos(_focus_priority);
            _drwer.require_create_in(_focus);
            _drwer.set_width(6);
        }
        @property Cell focus()const{
            return _focus;
        }
        @property Color color()const{
            return _color_priority[_focus_priority];
        }
    }

        @property Cell _colorbox_start_pos()const{
            return Cell(max_row()/2,0);
        }
        @property int _colorbox_turn_column()const{
            return max_col();
        }
        static int _c_row,_c_col,_c_cnt;
        public void add_color(in Color c){
            int priority;
            if(c !in _color_box)
            {
                priority = _c_cnt++;
                _color_priority[priority] = c;
                _priority_color[c] = priority;
                auto ib = new CircleBOX(_table,this);
                _color_box[c] = ib;
            }else
                priority = _priority_color[c];

            auto cb = _color_box[c];
            cb.require_create_in(calc_colorpos(priority));
            cb.set_drawer();
            cb.set_color(c);
        }
        private Cell calc_colorpos(in int priority)const{
            auto row = (priority) / _colorbox_turn_column;
            auto col = (priority) % _colorbox_turn_column;
            return Cell(row,col) + _colorbox_start_pos;
        }
        private void reset_color_box(){
            void clear(){
                foreach(b; _color_box)
                    b.remove_from_table();
            }
            clear();
            _color_box_back = new RectBOX(_table,this);
            _color_box_back.hold_tl(Cell(max_row()-3,0),5,max_col()+1);
            _color_box_back.set_drawer();
            _color_box_back.set_color(_down_accent);

            foreach(c; _color_priority)
                add_color(c);
        }
        Color _selected_color;
        int max_row()const{
            return cast(int)(_holding_area.h / _gridSpace);
        }
        int max_col()const{
            return cast(int)(_holding_area.w / _gridSpace);
        }
        private TextBOX _debug_msg;
        // double _debug_pos_div=3/10;
        string _debug_str;
        void _renderDebug(Context cr){
            _render_text.fill(cr,_debug_msg,Color(dimgray,128));
            if(_debug_str)
                _render_text.render(cr,_debug_msg,true);
        }
    public:
        void set_msg(string d){
            _debug_msg.text_clear();
            _debug_msg.append(d);
            if(d != _debug_str)
                queueDraw();
            _debug_str = d;
        }
        this(){ 
            setProperty("can-focus",0);

            _table = new BoxTable(_gridSpace);
            _selector_table = new BoxTable(_gridSpace);
            _holding_area = new Rect(0,0,200,200);
            _render_text = new RenderTextBOX(this);
            _selected_color_box = new RectBOX(_table,this);
            _back_color = new RectBOX(_table,this);

            reset_color_box();

            // set_color_box()の後でないと初回の規定色得られなくて
            _color_selector = new ColorSelector();

            addOnSizeAllocate(&when_sizeallocated);
            addOnDraw(&draw_callback);
            addOnButtonPress(&onButtonPress);

            showAll();
        }
        void select_color(in Direct dir){
            _color_selector.move(dir);
        }
        double get_x(in Cell c)const{ return c.column * _gridSpace ; }
        double get_y(in Cell c)const{ return c.row * _gridSpace ; }

        int get_gridSize()const{
            return _gridSpace;
        }
        const(Rect) get_holdingArea()const{
            return _holding_area;
        }
        void display_color(in Color c){
            if(c !in _color_box)
                add_color(c);
            _selected_color = c;
        }
        void display_color(){
            display_color(_color_selector.color);
        }
        Color get_selectedColor()const{
            return _color_selector.color;
        }
}

