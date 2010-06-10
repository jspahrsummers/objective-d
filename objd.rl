import std.c.stdlib;
import std.stream;

%%{
    machine objd;
    
    newline = '\n' @{ ++line; };
    
    main := digit+ '\n';
    
    write data;
}%%

// four kilobytes at a time
immutable READ_SIZE = 4096;

void lex (string filename) {
    File fd = new File(filename);

    char[] preserved;
    char* ts, te;
    int cs, act;
    ulong line = 1;
    %% write init;

    size_t tdiff;
    while (!fd.eof) {
        char[] str = readString(READ_SIZE);
        if (preserved) {
            str = preserved ~ str;
            preserved = null;
        }
        
        ts = str.ptr;
        if (tdiff)
            te = ts + tdiff;
    
        char* p = str.ptr;
        char* pe = p + str.length;
        char* eof;
        if (fd.eof)
            eof = pe;
        else
            eof = null;
    
        %% write exec;
        
        if (ts) {
            size_t len = pe - ts;
            preserved = new char[len];
            memcpy(preserved.ptr, ts, len);
            tdiff = te - ts;
        } else
            tdiff = 0;
    }
    
    fd.close();
}