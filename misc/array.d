module misc.array;
import std.array;
import std.algorithm;

void remove(T)(ref T[] array,T del){
    foreach(i,a ; array)
    {
        if(a == del)
        {
            auto init = array[0 .. i];
            auto tail = array[i+1 .. $];
            array = init ~ tail;
            return;
        }
    }
    // 空配列は通す
}
void remove(T)(ref T[] array,int del_num){
    foreach(i,a ; array)
    {
        if(i == del_num)
        {
            auto init = array[0 .. i];
            auto tail = array[i+1 .. $];
            array = init ~ tail;
            return;
        }
    }
}
bool is_in(T)(const T[] array,const T b){ // some kind of search
    foreach(a; array){
        if(a == b) return true;
        else continue;
    }
    return false;
}
T max_in(T)(const T[] array){
    auto copy = array.dup;
    copy.sort();
    return copy[$-1];
}