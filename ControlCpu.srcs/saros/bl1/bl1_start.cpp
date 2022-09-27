
extern "C" void bl1_start();

void test_func() {
    volatile signed char *array1 = (signed char *)0x6129;
    volatile short *array2 = (short *)0x6928;
    volatile int *array3 = (int *)0x5190;

    int i, j=0x7e;
    //int acc = 0;

    for( i=0; i<4; ++i ) {
        array1[i] = ++j;
    }
    for( i=0; i<4; ++i ) {
        array2[i] = ++j;
    }
    for( i=0; i<4; ++i ) {
        array3[i] = ++j;
    }

    for( i=0; i<4; ++i ) {
        array3[i] = array1[i];
    }
}

void bl1_start() {
    test_func();
}
