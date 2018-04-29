#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <ctype.h>
#include <string.h>
#include <stdint.h>

#include "lodepng.h"
#include "kvec.h"

typedef struct pixel_t {
   unsigned char r;
   unsigned char g;
   unsigned char b;
   unsigned char a;
} pixel_t;

typedef struct cidr_t {
   uint32_t ip[4];
   uint32_t mask;
} cidr_t;

typedef kvec_t(struct cidr_t) cidrs_v;

char* in_file ="test.cidr";
char* in_png  = 0;
char* out_png = "out.png";
unsigned int power = 0;
unsigned int size  = 256;
    
cidr_t parse_cidr(char* line) {

    cidr_t cidr = {0};
    if(!isdigit(*line)) return cidr;

    int i = 0;
    // parse ip
    while (*line!=0 && *line!='/') {
        if (isdigit(*line)) {
            cidr.ip[i] *= 10;
            cidr.ip[i] += *line - '0';
        } else {
            i++;
        }
        line++;
    }
    line++;

    // parse mask
    while (*line>='0' && *line<='9') {
        cidr.mask *= 10;
        cidr.mask += *line - '0';
        line++;
    }
    return cidr;
}

//rotate/flip a quadrant appropriately
void rot(int n, int *x, int *y, int rx, int ry) {
    if (ry == 0) {
        if (rx == 1) {
            *x = n-1 - *x;
            *y = n-1 - *y;
        }
 
        //Swap x and y
        int t  = *x;
        *x = *y;
        *y = t;
    }
}

//convert (x,y) to d
int xy2d (int n, int x, int y) {
    int rx, ry, s, d=0;
    for (s=n/2; s>0; s/=2) {
        rx = (x & s) > 0;
        ry = (y & s) > 0;
        d += s * s * ((3 * rx) ^ ry);
        rot(s, &x, &y, rx, ry);
    }
    return d;
}
 
//convert d to (x,y)
void d2xy(int n, int d, int *x, int *y) {
    int rx, ry, s, t=d;
    *x = *y = 0;
    for (s=1; s<n; s*=2) {
        rx = 1 & (t/2);
        ry = 1 & (t ^ rx);
        rot(s, x, y, rx, ry);
        *x += s * rx;
        *y += s * ry;
        t /= 4;
    }
}

cidrs_v read_cidrs(char* filename) {

    cidrs_v cidrs;
    kv_init(cidrs);
    
    char *line = NULL;
    size_t size;
    FILE* in = fopen(filename, "r");
    while(getline(&line, &size, in) > 0) {
        cidr_t cidr = parse_cidr(line);
        fprintf(stderr, 
            "%.*s\n%d.%d.%d.%d/%d ", 
            strlen(line)-1, line,
            cidr.ip[0], 
            cidr.ip[1], 
            cidr.ip[2], 
            cidr.ip[3], 
            cidr.mask);
        if(cidr.mask>=1 && cidr.mask<=32) {
            kv_push(cidr_t, cidrs, cidr);
            fprintf(stderr, "OK\n");
        } else {
            fprintf(stderr, "ERR\n");
        }
    };
    fclose(in);    
    free(line);
    
    return cidrs;
}

void draw_cidr(cidr_t* cidr, pixel_t* canvas) {
    uint32_t mask = (-1)<<(32-cidr->mask);
    uint32_t netstart = cidr->ip[0]<<24 | cidr->ip[1]<<16 | cidr->ip[2]<< 8 | cidr->ip[3] & mask;
    uint32_t netend   = netstart | ~mask;
    fprintf(stderr, "%x/%d >> %x\n", netstart, cidr->mask, netend);
    netstart >>= 2*(8-power);
    netend   >>= 2*(8-power);
    fprintf(stderr, "%x >> %x\n", netstart, netend);
    for(size_t i=netstart; i<=netend; i++) {
        int x, y, p;
        d2xy(size, i, &x, &y);
        p = x+y*size;
        canvas[p].r+=(255-canvas[p].r)>>1;
        canvas[p].g+=(255-canvas[p].g)>>1;
        canvas[p].b+=(255-canvas[p].b)>>1;
        canvas[p].a = 255;
    }
}

void draw_cidrs(cidrs_v cidrs, pixel_t* canvas) {
    for(size_t i=0; i<cidrs.n; i++) {
        draw_cidr(&cidrs.a[i], canvas);
    }
}

int main(int argc, char** argv){
    if(argc==1) {
       fprintf(stderr, 
       "Usage: ./hilbert file.cidr [image_power [update.png] [result.png]]\n"
       "\tfile.cidr lines with ranges like '192.168.0.0/16'\n"
       "\timage_power - 0..8, size of image, 0-256x256, 1-512x512, ...\n"
       "\tupdate.png - image to update\n"
       "\tresult.png - output image\n");
       exit(1);
    }
    if(argc>=2) in_file = argv[1];
    if(argc>=3 && *argv[ 2 ]>='0' && *argv[2]<='8') {
       power = *argv[2]-'0';
       size  = 1<<(power+8);
    }
    
    pixel_t* canvas = NULL;
    if(argc==4) {
        out_png = argv[3];
        canvas  = calloc(size*size, sizeof(pixel_t));
        for(size_t i=0; i<size*size; i++) canvas[i] = (pixel_t){0,0,0,255};
    } else if(argc==5) {
        in_png  = argv[3];
        unsigned error;
        unsigned width, height;
        error = lodepng_decode32_file((unsigned char**)&canvas, &width, &height, in_png);
        if(error) {
            fprintf(stderr, "error %u: %s\n", error, lodepng_error_text(error));
            goto error;
        }
        if(width!=size || height!=size) {
            fprintf(stderr, "error: input image size must be %dx%dpx\n", size, size);
            goto error;
        }
        out_png = argv[4];
    };
    
    cidrs_v cidrs = read_cidrs(in_file);
    draw_cidrs(cidrs, canvas);
    kv_destroy(cidrs);
    
    unsigned error = lodepng_encode32_file(out_png, (unsigned char*)canvas, size, size);
    if(error) printf("error %u: %s\n", error, lodepng_error_text(error));

error:
    free(canvas);
}

