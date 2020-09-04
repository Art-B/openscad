#include <mutex>
#include <string>
#include <fstream>
#include <streambuf>
#include <unistd.h>
#include <sys/resource.h>
#include <sys/utsname.h>

#include <boost/regex.hpp>
#include <boost/lexical_cast.hpp>
#include <boost/algorithm/string.hpp>
#include <boost/filesystem.hpp>

#include "version.h"
#include "../common/PlatformUtils.h"

namespace fs=boost::filesystem;

static std::mutex user_agent_mutex;

static std::string readText(const std::string &path)
{
    std::ifstream s{path.c_str()};
    s.seekg(0, std::ios::end);
    if (s.fail() || s.tellg() > 4096) {
	return "";
    }
    s.seekg(0, std::ios::beg);

    std::string text{(std::istreambuf_iterator<char>(s)), std::istreambuf_iterator<char>()};
    return text;
}

// see http://standards.freedesktop.org/basedir-spec/basedir-spec-latest.html
static fs::path getXdgConfigDir()
{
	const char *xdg_env = getenv("XDG_CONFIG_HOME");
	if (xdg_env && fs::exists(fs::path{xdg_env})) {
		return fs::path{xdg_env};
	} else {
		const char *home = getenv("HOME");
		if (home) {
			return fs::path{home} / ".config";
		}
	}

	return fs::path{};
}

// see https://www.freedesktop.org/wiki/Software/xdg-user-dirs/
// This partially implements the xdg-user-dir handling by reading the
// user-dirs.dirs file generated by the xdg-user-dirs-update tool. Missing
// is any handling of shell style quotes so this may fail with unusual
// setup.
static std::string getXdgUserDir(const std::string &dir)
{
	const fs::path config_dir = getXdgConfigDir() / "user-dirs.dirs";
	const std::string user_dirs{readText(config_dir.generic_string())};

	boost::smatch results;
	boost::regex documents_dir{"^" + dir + "=\"[$]HOME/([^\"]+)\""};
	if (boost::regex_search(user_dirs, results, documents_dir)) {
		return results[1];
	}

	return "";
}

std::string PlatformUtils::pathSeparatorChar()
{
	return ":";
}

std::string PlatformUtils::userDocumentsPath()
{
	fs::path user_documents_path;

	const char *xdg_env = getenv("XDG_DOCUMENTS_DIR");
	if (xdg_env && fs::exists(fs::path(xdg_env))) {
		user_documents_path = fs::path(xdg_env);
	} else {
		const char *home = getenv("HOME");
		if (home) {
			fs::path home_path{home};
			const auto user_dirs = getXdgUserDir("XDG_DOCUMENTS_DIR");
			if (!user_dirs.empty() && fs::exists(home_path / user_dirs)) {
				user_documents_path = home_path / user_dirs;
			} else if (fs::exists(fs::path(home))) {
				user_documents_path = fs::path(home);
			}
		}
	}

	if (fs::is_directory(user_documents_path)) {
		return fs::absolute(user_documents_path).generic_string();
	}

	return "";
}

std::string PlatformUtils::documentsPath()
{
	const char *home = getenv("HOME");
	if (home) {
		fs::path docpath(home);
		docpath = docpath / ".local" / "share";
		return docpath.generic_string();
	}
	else {
		return "";
	}
}

std::string PlatformUtils::userConfigPath()
{
    const fs::path config_path{getXdgConfigDir() / OPENSCAD_FOLDER_NAME};

    if (fs::is_directory(config_path)) {
	return fs::absolute(config_path).generic_string();
    }
    
    return "";
}

unsigned long PlatformUtils::stackLimit()
{
    struct rlimit limit;

    int ret = getrlimit(RLIMIT_STACK, &limit);
    if (ret == 0) {
        if (limit.rlim_cur == RLIM_INFINITY) {
	  return STACK_LIMIT_DEFAULT;
        }
	if (limit.rlim_cur > STACK_BUFFER_SIZE) {
	    return limit.rlim_cur - STACK_BUFFER_SIZE;
	}
        if (limit.rlim_max == RLIM_INFINITY) {
          return STACK_LIMIT_DEFAULT;
        }
	if (limit.rlim_max > STACK_BUFFER_SIZE) {
	    return limit.rlim_max - STACK_BUFFER_SIZE;
	}
    }

    return STACK_LIMIT_DEFAULT;
}

/**
 * Check /etc/os-release as defined by systemd.
 * @see http://0pointer.de/blog/projects/os-release.html
 * @see http://www.freedesktop.org/software/systemd/man/os-release.html
 * @return the PRETTY_NAME from the os-release file or an empty string.
 */
static const std::string checkOsRelease()
{
    std::string os_release(readText("/etc/os-release"));

    boost::smatch results;
    boost::regex pretty_name("^PRETTY_NAME=\"([^\"]+)\"");
    if (boost::regex_search(os_release, results, pretty_name)) {
	return results[1];
    }

    return "";
}

static const std::string checkEtcIssue()
{
    std::string issue(readText("/etc/issue"));

    boost::regex nl("\n.*$");
    issue = boost::regex_replace(issue, nl, "");
    boost::regex esc("\\\\.");
    issue = boost::regex_replace(issue, esc, "");
    boost::algorithm::trim(issue);
    
    return issue;
}

static const std::string detectDistribution()
{
    std::string osrelease = checkOsRelease();
    if (!osrelease.empty()) {
	return osrelease;
    }

    std::string etcissue = checkEtcIssue();
    if (!etcissue.empty()) {
	return etcissue;
    }
    
    return "";
}

static const std::string get_distribution(const std::string& separator)
{
	std::string result;
    std::string distribution = detectDistribution();
    if (!distribution.empty()) {
			result += separator;
			result += distribution;
    }
	return result;
}

static const std::string get_system_info(bool extended = true)
{
    std::string result;

    struct utsname osinfo;
    if (uname(&osinfo) == 0) {
			result += osinfo.sysname;
			result += " ";
			if (extended) {
				result += osinfo.release;
				result += " ";
				result += osinfo.version;
				result += " ";
			}
			result += osinfo.machine;
    } else {
			result += "Unknown Unix";
    }

	return result;
}

const std::string PlatformUtils::user_agent()
{
    static std::string result;

    std::lock_guard<std::mutex> lock(user_agent_mutex);

	if (result.empty()) {
		result += "OpenSCAD/";
		result += openscad_detailedversionnumber;
		result += " (";
		result += get_system_info(false);
		result += get_distribution("; ");
		result += ")";
	}

	return result;
}

const std::string PlatformUtils::sysinfo(bool extended)
{
    std::string result;

	result += get_system_info(true);
    result += get_distribution(" ");

	if (extended) {
		long numcpu = sysconf(_SC_NPROCESSORS_ONLN);
		if (numcpu > 0) {
			result += " ";
			result += boost::lexical_cast<std::string>(numcpu);
			result += " CPU";
			if (numcpu > 1) {
				result += "s";
			}
		}

		long pages = sysconf(_SC_PHYS_PAGES);
		long pagesize = sysconf(_SC_PAGE_SIZE);
		if ((pages > 0) && (pagesize > 0)) {
			result += " ";
			result += PlatformUtils::toMemorySizeString(pages * pagesize, 2);
			result += " RAM";
		}
	}

	return result;
}

void PlatformUtils::ensureStdIO(void) {}
