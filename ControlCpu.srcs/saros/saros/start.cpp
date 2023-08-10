
int somevar;

extern unsigned char HEAP_START[];

extern "C"
int _start() {
    return HEAP_START[0] + somevar;
}
