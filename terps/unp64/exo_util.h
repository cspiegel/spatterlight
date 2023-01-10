/* Code from Exomizer distributed under the zlib License
 * by kind permission of the original author
 * Magnus Lind.
 */

/*
 * Copyright (c) 2002 - 2023 Magnus Lind.
 *
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 * claim that you wrote the original software. If you use this software
 * in a product, an acknowledgment in the product documentation would be
 * appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 * misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 *
 */

/*
 C++ version based on code adapted to ScummVM by Avijeet Maurya
 */

#ifndef UNP64_EXO_UTIL_H
#define UNP64_EXO_UTIL_H

#include "types.h"

namespace Unp64 {

struct LoadInfo {
	int _basicTxtStart; /* in */
	int _basicVarStart; /* out */
	int _run;           /* out */
	int _start;         /* out */
	int _end;           /* out */
};

int findSys(const uint8_t *buf, int target);

void loadData(uint8_t *data, size_t dataLength, uint8_t mem[65536], LoadInfo *info);

int strToInt(const char *str, int *value);

} // End of namespace Unp64

#endif
