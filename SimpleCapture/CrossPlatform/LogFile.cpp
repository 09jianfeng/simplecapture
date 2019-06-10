#include <iomanip>
#include <dirent.h>
#include <sys/stat.h>
#include <sstream>
#include <map>
#ifdef __APPLE__
#include <sys/time.h>
#else
#include <time.h>
#endif
#include<unistd.h>
#include "LogFile.h"
#include "mediabase_utils.h"

LogFile  *LogFile::m_logFile   = NULL;
bool      LogFile::m_stopped   = false;
pthread_t LogFile::m_pthreadId = 0;

const uint32_t    MAX_FILE_SIZE     = 1024 * 1024 * 5;               // 5M
const uint32_t    ROTATED_FILE_SIZE = 3;

#ifdef YCMEDIA_SDK
const std::string LOGFILE_PREFIX    = "ycmediaSdk-";
#else
const std::string LOGFILE_PREFIX    = "mediaSdk-";
#endif

const std::string LOGFILE_SUFFIX    = ".bak";

void *mediaThreadRun(void *param)
{
    LogFile::Instance()->writeLog();
	return NULL;
}

LogFile::LogFile()
{
    m_threadErrNo = -1;
    m_logNumIn    = 0;
    m_logNumOut   = 0;
    m_fp          = NULL;
	m_logPath.empty();
    m_logList.clear();

    startTread();
}

LogFile::~LogFile()
{
	m_logPath.empty();
    m_threadErrNo = -1;

    if (m_fp != NULL)
    {
        fclose(m_fp);
        m_fp = NULL;
    }
}

LogFile *LogFile::Instance()
{
    if (m_logFile == NULL)
    {
       m_logFile = new LogFile();
    }

    return m_logFile;
}

void LogFile::release()
{
    m_stopped = true;
    pthread_join(m_pthreadId, NULL);
    if (m_logFile != NULL)
	{
		delete m_logFile;
		m_logFile = NULL;
	}
}

void LogFile::startTread()
{
    m_threadErrNo = pthread_create(&m_pthreadId, NULL, &mediaThreadRun, NULL);
}

void LogFile::writeLog()
{
	setThreadName();
    while (!m_stopped)
    {
        timeval tv;
        tv.tv_sec  = 0;
        tv.tv_usec = 1000 * 50;
        select(1, NULL, NULL, NULL, &tv);

        uint64_t logNumIn = m_logNumIn;
        while (logNumIn > m_logNumOut + 1 && !m_stopped)
        {
            if (!writeLogToFile(m_logList.back()))
                break;

            m_logList.pop_back();
            ++m_logNumOut;
        }
    }
}

bool LogFile::writeLogToFile(const std::string &msg)
{
    if (m_fp == NULL)
        openLogFile();

    if (m_fp != NULL)
    {
        fseek(m_fp, 0L,SEEK_END);
        if ((uint32_t)ftell(m_fp) > MAX_FILE_SIZE)
        {
            fclose(m_fp);
			m_fp = NULL;
            rotateFileName();
            openLogFile();
        }
    }

    if (m_fp == NULL)
        return false;

	int len = fprintf(m_fp, "%s\n", msg.c_str());
	if (len < 0)
	{
		fclose(m_fp);
		m_fp = NULL;

		return false;
	}

    return true;
}

void LogFile::openLogFile()
{
    std::string path = m_logPath;
    if (path.empty())
        return;

    if (access(path.c_str(), 0) != 0 && !mkdirIterative(path))
        return;

    std::string logFileName = getLogFileName();
    if (logFileName.empty())
        return;

    m_fp = fopen(logFileName.c_str(), "a");
}

bool LogFile::mkdirIterative(const std::string &path)
{
    if (path.empty())
        return false;

    if (path == "/")
        return true;

    char separator = '/';
    std::string::size_type pos = path.find_first_not_of(separator);
    if (pos == std::string::npos)
        return false;

    bool        isSucc  = true;
    std::string subPath = "";
    while (subPath != path && isSucc)
    {
        pos = path.find_first_of(separator, pos + 1);
        if (pos == std::string::npos)
            subPath = path;
        else
            subPath = path.substr(0, pos);

        if (access(subPath.c_str(), 0) != 0 && mkdir(subPath.c_str(), 0755) != 0)
            isSucc = false;    
    }

    return isSucc;
}

void LogFile::rotateFileName()
{
	std::string path = m_logPath;
	if (path.empty() || access(path.c_str(), 0) != 0)
		return;

	std::string oldName = getLogFileName();
	std::string newName = getRotatedLogFileName();
	if (oldName.empty() || newName.empty() || access(oldName.c_str(), 0))
		return;

	if (rename(oldName.c_str(), newName.c_str()) != 0)
		return;

	DIR *dp;
	if ((dp = opendir(path.c_str())) == NULL)
		return;

	std::map<time_t, std::string> dateOfFiles;

	struct dirent *dirp;
	while ((dirp = readdir(dp)) != NULL)
	{
		std::string name = dirp->d_name;
		if (name.length() < LOGFILE_PREFIX.length() || name.length() < LOGFILE_SUFFIX.length())
			continue;

		if (name.substr(0, LOGFILE_PREFIX.length()) != LOGFILE_PREFIX)
			continue;

		if (name.substr(name.length() - LOGFILE_SUFFIX.length()) != LOGFILE_SUFFIX)
			continue;

		struct stat fileInfo;
		std::string fullFileName = path + "/" + name;
		if (stat(fullFileName.c_str(), &fileInfo) != 0)
			continue;

		dateOfFiles[fileInfo.st_mtime] = fullFileName;
	}

	closedir(dp);
	if (dateOfFiles.size() <= ROTATED_FILE_SIZE)
		return;

	uint32_t num = 0;
	for (std::map<time_t, std::string>::reverse_iterator it = dateOfFiles.rbegin(); it != dateOfFiles.rend(); ++it)
	{
		if (++num <= ROTATED_FILE_SIZE)
			continue;

		remove(it->second.c_str());
	}
}

std::string LogFile::getLogFileName()
{
    std::string fileName = "";
    std::string path     = m_logPath;
    std::string appName  = "trans";
    if (!path.empty() && !appName.empty())
        fileName = path + "/" + LOGFILE_PREFIX + appName + ".txt";

    return fileName;
}

std::string LogFile::getLogPath()
{
	return m_logPath + "/";
}

std::string LogFile::getFileName()
{
	std::string appName  = "trans";
	return LOGFILE_PREFIX + appName + ".txt";
}

void LogFile::getFileList(std::list<std::string>& file_list)
{
	std::string path = m_logPath;
	if (path.empty() || access(path.c_str(), 0) != 0)
		return;

	DIR *dp;
	if ((dp = opendir(path.c_str())) == NULL)
		return;

	struct dirent *dirp;
	while ((dirp = readdir(dp)) != NULL)
	{
		std::string name = dirp->d_name;
		if (name == ".." || name == ".")
		{
			continue;
		}

		struct stat fileInfo;
		std::string fullFileName = path + "/" + name;
		if (stat(fullFileName.c_str(), &fileInfo) != 0)
			continue;
		file_list.push_back(fullFileName);
	}

	closedir(dp);
}

std::string LogFile::getRotatedLogFileName()
{
    std::string oldName = getLogFileName();
    if (oldName.empty())
        return "";

    struct timeval curTime;
    gettimeofday(&curTime, NULL);

    char MMddHHmmss[20];
    strftime(MMddHHmmss, sizeof(MMddHHmmss), "%m-%d-%H-%M-%S", localtime(&curTime.tv_sec));

    std::string newName = oldName + "-" + MMddHHmmss + LOGFILE_SUFFIX;

    return newName;
}

void LogFile::log(const std::string &msg)
{
    if (m_stopped || m_threadErrNo != 0)
        return;

    // 暂存设置路径前的log
    if (m_logPath.empty() && m_logNumIn - m_logNumOut > 100)
        return;

    // log 打的太多
    if (m_logNumIn - m_logNumOut > 5000)
        return;

    std::string info = "";
    info += getCurrentTimeString() + " ";
    info += msg;

    MutexStackLock lock(m_lock);
    m_logList.push_front(info);
    ++m_logNumIn;
}

std::string LogFile::getCurrentTimeString()
{
    struct timeval curTime;
    gettimeofday(&curTime, NULL);

    char buf[100];
    strftime(buf, sizeof(buf), "%F %T", localtime(&curTime.tv_sec));

    std::ostringstream os;
    os << buf << "." << std::setfill('0') << std::setw(3) << (curTime.tv_usec / 1000);

    return os.str();
}

void LogFile::setLogPath( const std::string& logPath )
{
	if (!logPath.empty())
	{
		m_logPath = logPath;
	}
}

//按业务方要求，取线程名字为YST_模块名，其中，模块名：sdk名+模块名简写
//man page说使用api prctl给线程起名字，最多只能16个字符，包括最后的null字符，多出来的会被截断
//实际测试中，ios没有此限制，android有
void LogFile::setThreadName()
{
	char threadName[] = "YST_yyliveLog";
	MediaLibrary::SetThreadName(threadName);
}
