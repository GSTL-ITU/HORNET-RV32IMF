#include "math.h"
#include <stdio.h>

int main() {
        //filter coefficients
    volatile float a0 = 1.363f;
    volatile float a2 = 2.543f;
    volatile float b1 = 0.0f;
    volatile float b2 = 1.0f;
    volatile float a1 = 0.73f;

    //initial values
    volatile float x1 = 0.23f;
    volatile float x2 = -0.1324f;
    volatile float y_1 = 0.452f;
    volatile float y2 = 0.7435f;

    //inputs

    const float inputSignal[23] = {0.52f, 0.56f, -0.5f, 0.36f, -0.543222344f, 0.5f, -0.5f, 0.34521f,
     -0.5f, 0.67324f, 0.0f, 0.124252f, 0.6254234f, 0.12562345f, 0.0f, 0.0f, 0.0f, -0.785675646f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f};
    volatile float x = 0.0f;
    volatile float y = 0.0f;

    char c;

    for (int i = 0; i < 23; i++) {
        x = inputSignal[i];
        
        y = a0 * x + a1 * x1 + a2 * x2 - b1 * y_1 - b2 * y2;
        y = x * a2 * y;

        if(fabs(y - (-0.269144f)) < 1e-4f){
            c = 'a';
        }
        else if (fabs(y - (1.816798f)) < 1e-4f){
            c = 'b';
        }
        else if (fabs(y - (-1.676859f)) < 1e-4f){
            c = 'c';
        }
        else if (fabs(y - (-0.244468f)) < 1e-4f){
            c = 'd';
        }
        else if (fabs(y - (0.099811f)) < 1e-4f){
            c = 'e';
        }
        else if (fabs(y - 1.837185f) < 1e-4f){
            c = 'f';
        }
        else if (fabs(y - (2.285808f)) < 1e-4f){
            c = 'g';
        }
        else if (fabs(y - (-0.403964f)) < 1e-4f){
            c = 'h';
        }
        else if (fabs(y - (5.069222f)) < 1e-4f){
            c = 'i';
        }
        else if (fabs(y - (3.140684f)) < 1e-4f){
            c = 'j';
        }
        else if (fabs(y - (-0.000000f)) < 1e-4f){
            c = 'k';
        }
        else if (fabs(y - (-0.397898f)) < 1e-4f){
            c = 'l';
        }
        else if (fabs(y - (1.5000441074f)) < 1e-4f){
            c = 'm';
        }
        else if (fabs(y - (0.428606f)) < 1e-4f){
            c = 'n';
        }
        else if (fabs(y - (2.139581f)) < 1e-4f){
            c = 'o';
        }
        else if (fabs(y - (0.000000f)) < 1e-4f){
            c = 'p';
        }
        else if (fabs(y - (-1.348073f)) < 1e-4f){
            c = 'q';
        }
        else if (fabs(y - (2.390810f)) < 1e-4f){
            c = 'r';
        }
        else if (fabs(y - (-0.649900f)) < 1e-4f){
            c = 's';
        }
        else if (fabs(y - (-2.390810f)) < 1e-4f){
            c = 't';
        }
        else if (fabs(y - (0.649900f)) < 1e-4f){
            c = 'u';
        }
        else if (fabs(y - (2.390810f)) < 1e-4f){
            c = 'v';
        }
        else{
            c = 'X';
        }
        putchar(c);

        x2 = x1;
        x1 = x;
        y2 = y_1;
        y_1 = y;
    }
    putchar('\n');

    return 0;
}