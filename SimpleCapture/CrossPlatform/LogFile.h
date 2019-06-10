#ifndef _LOGFILE_H
#define _LOGFILE_H

#include <list>
#include <string>
#include "commonutils.h"

class LogFile
{
private:
    LogFile();

public:
    ~LogFile();
    static LogFile *Instance();
    static void release();

private:
    bool writeLogToFile(const std::string &msg);
    bool mkdirIterative(const std::string &path);
    void startTread();
    void rotateFileName();
    void openLogFile();
    std::string getRotatedLogFileName();
    std::string getCurrentTimeString();

public:
	std::string getLogFileName();
	std::string getLogPath();
	std::string getFileName();
	void getFileList(std::list<std::string>& file_list);

public:
    void writeLog();
    void log(const std::string &msg);
	void setLogPath(const std::string& logPath);

private:
	void setThreadName();

private:
    typedef std::list<std::string>    StringList_t;

private:
    static LogFile                  *m_logFile;
    static bool                      m_stopped;
    static pthread_t                 m_pthreadId;

    int                              m_threadErrNo;
    StringList_t                     m_logList;
    MediaMutex                       m_lock;
    FILE                            *m_fp;
	std::string						 m_logPath;
    volatile uint64_t                m_logNumIn;
    volatile uint64_t                m_logNumOut;
};

#endif
