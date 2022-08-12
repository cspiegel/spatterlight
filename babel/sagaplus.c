/* scott.c  Treaty of Babel module for Saga Plus files
 * GPL license.
 *
 * This file depends on treaty_builder.h
 */

#define FORMAT sagaplus
#define HOME_PAGE "https://github.com/angstsmurf/spatterlight/tree/master/terps/plus"
#define FORMAT_EXT ".dat,.d64,.atr,.st,.msa,.dsk"
#define NO_METADATA
#define NO_COVER

#define MAX_LENGTH 368641
#define MIN_LENGTH 24

#define MIN(a, b) ((a) < (b) ? (a) : (b))
#define MAX(a, b) ((a) > (b) ? (a) : (b))

#include "treaty_builder.h"
#include <ctype.h>
#include <stdlib.h>
#include <stdbool.h>

struct plusrec {
    int32 length;
    uint16_t chk;
    const char *id;
    const char *ifid;
};

static const struct plusrec plus_registry[] = {
    { 0, 0, "SPIDER-MAN (tm)", "DAEE386546CE71831DC365B0FF10F233" }, // Spider-Man MS-DOS
    { 0x2ab00, 0x833c, "SPIDER-MAN (tm)", "DAEE386546CE71831DC365B0FF10F233" }, // questprobe_spider-man[gvp_1985](!).d64
    { 0x2ab00, 0x83dc, "SPIDER-MAN (tm)", "DAEE386546CE71831DC365B0FF10F233" }, // questprobe_spider-man[gvp_1985](!).d64
    { 0x2ab00, 0xe1cd, "SPIDER-MAN (tm)", "DAEE386546CE71831DC365B0FF10F233" }, // questprobe_spider-man[sharedata_1987].d64
    { 0x16810, 0xc003, "SPIDER-MAN (tm)", "DAEE386546CE71831DC365B0FF10F233" }, // atr
    { 0x5a000, 0x973b, "SPIDER-MAN (tm)", "DAEE386546CE71831DC365B0FF10F233" }, // st
    { 0x23000, 0xc267, "SPIDER-MAN (tm)", "DAEE386546CE71831DC365B0FF10F233" }, // apple 2
    { 0, 0, "Sorcerer of Claymorgue Castle. SAGA#13.", "B5AF6E4DB3C3B2118FAEA3849F807617" }, // Claymorgue MS-DOS
    { 0x5a000, 0xcc3, "Sorcerer of Claymorgue Castle. SAGA#13.", "B5AF6E4DB3C3B2118FAEA3849F807617" }, // st
    { 0, 0, "BUCKAROO", "13EA7A22731E90598456D13311923833" },
    { 0x2ab00, 0x3464, "BUCKAROO", "13EA7A22731E90598456D13311923833" }, // BuckarooBanzai.d64
    { 0x16810, 0x5434, "BUCKAROO", "13EA7A22731E90598456D13311923833" }, // Buckaroo Banzai Atari 8-bit
    { 0x23000, 0x3d97, "BUCKAROO", "13EA7A22731E90598456D13311923833" }, // Buckaroo Banzai Apple 2
    { 0x23000, 0xca17, "BUCKAROO", "13EA7A22731E90598456D13311923833" }, // Buckaroo Banzai Apple 2 alt
    { 0, 0, "FF #1 ", "126E2481-30F5-46D4-ABDD-9339526F516B" }, // Fantastic Four MS-DOS
    { 0x2ab00, 0xec72, "FF #1 ", "126E2481-30F5-46D4-ABDD-9339526F516B" },
    { 0x2ab00, 0xd2c0, "FF #1 ", "126E2481-30F5-46D4-ABDD-9339526F516B" },
    { 0x16810, 0xe3ad, "FF #1 ", "126E2481-30F5-46D4-ABDD-9339526F516B" }, // Fantastic Four Atari 8-bit
    { 0x16810, 0x3c1e, "FF #1 ", "126E2481-30F5-46D4-ABDD-9339526F516B" }, // Fantastic Four Atari 8-bit
    { 0x23000, 0xa450, "FF #1 ", "126E2481-30F5-46D4-ABDD-9339526F516B" }, // Fantastic Four Apple 2
    { 0x3426a, 0x8ffa, "FF #1 ", "126E2481-30F5-46D4-ABDD-9339526F516B" }, // Fantastic Four Atari ST

    { 0, 0, "\0", "\0" }
};

/* All numbers in Saga Plus text format files are stored as text delimited by whitespace */
static int read_next_number(unsigned char *text, int32_t extent, int32_t *offset, bool *failure) {
    char numstring[100];
    int i;
    bool number_found = false;

    char c = text[*offset];
    if (c == ',')
        *offset = *offset + 1;
    for (i = 0; i < extent - *offset && i < 99; i++) {
        c = text[*offset + i];
        numstring[i] = c;
        if (isspace(c) || c == ',') {
            if (number_found == true)
                break;
        } else if (isdigit(c) || c == '-') {
            number_found = true;
        } else {
            *failure = true;
            return 0;
        }
    }

    if (number_found == false) {
        *failure = true;
        return 0;
    }
    numstring[i+1] = '\0';
    *offset += i;
    int result = atoi(numstring);
    if (result > INT16_MAX || result < INT16_MIN)
        *failure = true;

    return result;
}

static int read_string(unsigned char *text, int32_t extent, int32_t *offset, bool *failure, bool checkforcomma)
{
    int c,nc;
    int ct=0;
    do {
        c=text[(*offset)++];
    } while(*offset < extent && isspace(c));
    
    if(c!='"') {
        *failure = true;
        return 0;
    }
    do {
        c=text[(*offset)++];
        if(*offset >= extent) {
            *failure = true;
            return 0;
        }
        if(c=='"') {
            nc=text[(*offset)++];
            if(nc!='"') {
                (*offset)--;
                break;
            }
        }
        if (checkforcomma && ct == 0 && c != ',') {
            *failure = true;
            return 0;
        }

        if (!isprint(c)) {
            *failure = true;
            return 0;
        }

       ct++;

    } while(*offset < extent);
    return ct;
}

static uint16_t checksum(unsigned char *sf, int32 extent)
{
    uint16_t c=0;
    for(int i = 0; i < extent; i++)
        c+=sf[i];
    return c;
}

static int32 find_dskimg_in_database(unsigned char *sf, int32 extent, char **ifid) {
    if (extent > MAX_LENGTH || extent < MIN_LENGTH)
        return INVALID_STORY_FILE_RV;

    uint16_t chksum = checksum(sf, extent);

    for (int i = 0; plus_registry[i].ifid[0] != '\0'; i++) {
        if (extent == plus_registry[i].length &&
            chksum == plus_registry[i].chk) {
            if (ifid != NULL) {
                size_t length = strlen(plus_registry[i].ifid);
                strncpy(*ifid, plus_registry[i].ifid, length);
                (*ifid)[length] = 0;
            }
            return VALID_STORY_FILE_RV;
        }
    }
    return INVALID_STORY_FILE_RV;
}

static int32 find_in_database(unsigned char *sf, int32 extent, char **ifid) {
    if (extent > MAX_LENGTH || extent < MIN_LENGTH)
        return INVALID_STORY_FILE_RV;

    int32 offset = 0;
    bool failure = false;

    read_string(sf, extent, &offset, &failure, false);
    if (failure == true)
        return INVALID_STORY_FILE_RV;

    char title[offset];
    if (offset < 2)
        return INVALID_STORY_FILE_RV;

    memcpy(title, sf + 1, offset);
    title[offset - 2] = 0;

    for (int i = 0; plus_registry[i].id[0] != 0; i++) {
        if (strcmp(plus_registry[i].id, title) == 0 ) {
            if (ifid != NULL) {
                size_t length = strlen(plus_registry[i].ifid);
                strncpy(*ifid, plus_registry[i].ifid, length);
                (*ifid)[length] = 0;
            }
            return VALID_STORY_FILE_RV;
        }
    }
    return INVALID_STORY_FILE_RV;
}


static int32 detect_sagaplus(unsigned char *storystring, int32 extent) {
    /* Load the header */

    int32 offset = 0;
    int header[18];
    bool failure = false;

    /* We simply run a sped-up version of the first three parts of reading the database
     * from the file, and bail at the first sign of failure.
     */

    read_string(storystring, extent, &offset, &failure, false);
    if (failure == true)
        return INVALID_STORY_FILE_RV;

    char title[offset];
    if (offset < 2)
        return INVALID_STORY_FILE_RV;

    memcpy(title, storystring + 1, offset);
    title[offset - 2] = 0;

    if (strcmp("SPIDER-MAN (tm)", title) != 0 &&
        strcmp("BUCKAROO", title) != 0 &&
        strcmp("Sorcerer of Claymorgue Castle. SAGA#13.", title) != 0 &&
        strcmp("FF #1 ", title) != 0) {
        fprintf(stderr, "title: \"%s\"\n", title);
        return INVALID_STORY_FILE_RV;
    }

    /* First the 18 integers of the header */
    for (int i = 0; i < 18; i++) {
        header[i] = read_next_number(storystring, extent, &offset, &failure);
        if (failure == true)
            return INVALID_STORY_FILE_RV;
    }

    /* Then the number of actions given in header[1] */
    for (int i = 0; i <= header[1]; i++) {
        int result = read_next_number(storystring, extent, &offset, &failure);
        if (failure == true || result > 255)
            return INVALID_STORY_FILE_RV;
    }

    /* Finally the number of verb strings given in header[3] */
    for (int i = 0; i <= header[3]; i++) {
        read_string(storystring, extent, &offset, &failure, true);
        if (failure == true)
            return INVALID_STORY_FILE_RV;
    }

    return VALID_STORY_FILE_RV;
}

static int32 claim_story_file(void *storyvp, int32 extent)
{
    unsigned char *storystring = (unsigned char *)storyvp;

    fprintf(stderr, "The length of this file is %x, and its checksum %x\n", extent, checksum(storystring, extent));

    if (extent < MIN_LENGTH || extent > MAX_LENGTH)
        return INVALID_STORY_FILE_RV;

    if (detect_sagaplus(storystring, extent) == VALID_STORY_FILE_RV)
        return VALID_STORY_FILE_RV;

    if (find_in_database(storystring, extent, NULL) == VALID_STORY_FILE_RV)
        return VALID_STORY_FILE_RV;

    return find_dskimg_in_database(storystring, extent, NULL);
}

static int32 get_story_file_IFID(void *storyvp, int32 extent, char *output, int32 output_extent)
{
    ASSERT_OUTPUT_SIZE(37);

    unsigned char *storystring = (unsigned char *)storyvp;

    if (detect_sagaplus(storystring, extent) == VALID_STORY_FILE_RV) {
        return find_in_database(storystring, extent, &output);
    }

    return (find_dskimg_in_database(storystring, extent, &output));
}
