/*
 * common.c
 *
 *  Created on: Nov 19, 2014
 *      Author: huangwanzhang
 */

#include "common.h"

#include "libavformat/avformat.h"

//add bhl
#include <sys/time.h>

//add bhl end

// NOTICE that this function is not thread safe
char * mytime(){
	time_t now = time (NULL);
	return ctime(&now);
}

int64_t getcurrenttime_us() {
	struct timeval te;
	gettimeofday(&te, NULL);
	int64_t useconds = te.tv_sec*1000*1000LL + te.tv_usec;
	return useconds;
}

/* warning: not support nested quotations*/
char ** argv_create(const char* cmd, int* count) {
	int i=-1, j=0, argc=0, max_argc = 16;
	char **argv = malloc(sizeof(char*) * max_argc);
	int found_quota = 0;
	char last_quota = 0;

	memset(argv, 0, sizeof(char*)*max_argc);

	while(cmd[j] != '\0') {
		if(i>=0 && found_quota == 0 && cmd[j] == ' ') {

			if (j>0 && (cmd[j-1] == '\"' || cmd[j-1] == '\'')) {
				argv[argc] = malloc(j-i-1);
				argv[argc][j-i-2] = '\0';
				memcpy(argv[argc], cmd+i+1, j-i-2);
			}else {
				argv[argc] = malloc(j-i+1);
				argv[argc][j-i] = '\0';
				memcpy(argv[argc], cmd+i, j-i);
			}
			LOGI("%s", argv[argc]);
			argc++;
			i=-1;
		}

		if (i==-1 && found_quota == 0 && cmd[j] != ' '){
			i=j;
		}

		if(cmd[j]=='\"' || cmd[j] == '\'') {
			found_quota++;
			if (found_quota == 1) {
				last_quota = cmd[j];
			}
			else if (found_quota%2==0 && last_quota == cmd[j]) {
				found_quota = 0;
				last_quota = 0;
			}
		}
		j++;
	}

	if (i>=0) {
		if (j>0 && (cmd[j-1] == '\"' || cmd[j-1] == '\'')) {
			argv[argc] = malloc(j-i-1);
			argv[argc][j-i-2] = '\0';
			memcpy(argv[argc], cmd+i+1, j-i-2);
		}else {
			argv[argc] = malloc(j-i+1);
			argv[argc][j-i] = '\0';
			memcpy(argv[argc], cmd+i, j-i);
		}
		LOGI("%s", argv[argc]);
		argc++;
	}

	LOGI("argc: %d", argc);

	*count = argc;
	return argv;
}

/* remember to free argv */
void argv_free(char **argv, int argc) {
	int i=0;
	while(i<argc) {
		free(argv[i++]);
	}
	free(argv);
	return;
}

