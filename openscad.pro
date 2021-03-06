# Environment variables which can be set to specify library locations:
# MPIRDIR
# MPFRDIR
# BOOSTDIR
# CGALDIR
# EIGENDIR
# GLEWDIR
# OPENCSGDIR
# OPENSCAD_LIBRARIES
#
# qmake Variables to define the installation:
#
#   PREFIX defines the base installation folder
#
#   SUFFIX defines an optional suffix for the binary and the
#   resource folder. E.g. using SUFFIX=-nightly will name the
#   resulting binary openscad-nightly.
#
# Please see the 'Building' sections of the OpenSCAD user manual
# for updated tips & workarounds.
#
# https://en.wikibooks.org/wiki/OpenSCAD_User_Manual

include(defaults.pri)

# Local settings are read from local.pri
exists(local.pri): include(local.pri)

# Auto-include config_<variant>.pri if the VARIANT variable is given on the
# command-line, e.g. qmake VARIANT=mybuild
!isEmpty(VARIANT) {
  message("Variant: $${VARIANT}")
  exists(config_$${VARIANT}.pri) {
    message("Including config_$${VARIANT}.pri")
    include(config_$${VARIANT}.pri)
  }
}

debug {
  experimental {
    message("Building experimental debug version")
  }
  else {
    message("If you're building a development binary, consider adding CONFIG+=experimental")
  }
}
  
# If VERSION is not set, populate VERSION, VERSION_YEAR, VERSION_MONTH from system date
include(version.pri)

debug: DEFINES += DEBUG

TEMPLATE = app

INCLUDEPATH += src
DEPENDPATH += src

# add CONFIG+=deploy to the qmake command-line to make a deployment build
deploy {
  message("Building deployment version")
  DEFINES += OPENSCAD_DEPLOY
  macx: {
    CONFIG += sparkle
    OBJECTIVE_SOURCES += src/osx/SparkleAutoUpdater.mm
    QMAKE_RPATHDIR = @executable_path/../Frameworks
  }
}
snapshot {
  DEFINES += OPENSCAD_SNAPSHOT
}
# add CONFIG+=idprefix to the qmake command-line to debug node IDs in csg output
idprefix {
  DEFINES += IDPREFIX
  message("Setting IDPREFIX for csg debugging")
  warning("Setting IDPREFIX will negatively affect cache hits")
}  
macx {
  TARGET = OpenSCAD
}
else {
  TARGET = openscad$${SUFFIX}
}
FULLNAME = openscad$${SUFFIX}
APPLICATIONID = org.openscad.OpenSCAD
!isEmpty(SUFFIX): DEFINES += INSTALL_SUFFIX="\"\\\"$${SUFFIX}\\\"\""

macx {
  snapshot {
    ICON = icons/icon-nightly.icns
  }
  else {
    ICON = icons/OpenSCAD.icns
  }
  QMAKE_INFO_PLIST = Info.plist
  APP_RESOURCES.path = Contents/Resources
  APP_RESOURCES.files = OpenSCAD.sdef dsa_pub.pem icons/SCAD.icns
  QMAKE_BUNDLE_DATA += APP_RESOURCES
  LIBS += -framework Cocoa -framework ApplicationServices
  QMAKE_MACOSX_DEPLOYMENT_TARGET = 10.9
}

# Set same stack size for the linker and #define used in PlatformUtils.h
STACKSIZE = 8388608 # 8MB # github issue 116
QMAKE_CXXFLAGS += -DSTACKSIZE=$$STACKSIZE
DEFINES += STACKSIZE=$$STACKSIZE

win* {
  RC_FILE = openscad_win32.rc
  QMAKE_CXXFLAGS += -DNOGDI
  QMAKE_LFLAGS += -Wl,--stack,$$STACKSIZE
}

mingw* {
  # needed to prevent compilation error on MSYS2:
  # as.exe: objects/cgalutils.o: too many sections (76541)
  # using -Wa,-mbig-obj did not help
  debug: QMAKE_CXXFLAGS += -O1
}

CONFIG += qt object_parallel_to_source
QT += widgets concurrent multimedia network
CONFIG += scintilla

netbsd* {
   QMAKE_LFLAGS += -L/usr/X11R7/lib
   QMAKE_LFLAGS += -Wl,-R/usr/X11R7/lib
   QMAKE_LFLAGS += -Wl,-R/usr/pkg/lib
   # FIXME: Can the lines below be removed in favour of the OPENSCAD_LIBDIR handling above?
   !isEmpty(OPENSCAD_LIBDIR) {
     QMAKE_CFLAGS = -I$$OPENSCAD_LIBDIR/include $$QMAKE_CFLAGS
     QMAKE_CXXFLAGS = -I$$OPENSCAD_LIBDIR/include $$QMAKE_CXXFLAGS
     QMAKE_LFLAGS = -L$$OPENSCAD_LIBDIR/lib $$QMAKE_LFLAGS
     QMAKE_LFLAGS = -Wl,-R$$OPENSCAD_LIBDIR/lib $$QMAKE_LFLAGS
   }
}

# Prevent LD_LIBRARY_PATH problems when running the openscad binary
# on systems where uni-build-dependencies.sh was used.
# Will not affect 'normal' builds.
!isEmpty(OPENSCAD_LIBDIR) {
  unix:!macx {
    QMAKE_LFLAGS = -Wl,-R$$OPENSCAD_LIBDIR/lib $$QMAKE_LFLAGS
    # need /lib64 because GLEW installs itself there on 64 bit machines
    QMAKE_LFLAGS = -Wl,-R$$OPENSCAD_LIBDIR/lib64 $$QMAKE_LFLAGS
  }
}

# See Dec 2011 OpenSCAD mailing list, re: CGAL/GCC bugs.
*g++* {
  QMAKE_CXXFLAGS *= -fno-strict-aliasing
  QMAKE_CXXFLAGS_WARN_ON += -Wno-unused-local-typedefs # ignored before 4.8

  # Disable attributes warnings on MSYS/MXE due to gcc bug spamming the logs: Issue #2771
  win* | CONFIG(mingw-cross-env)|CONFIG(mingw-cross-env-shared) {
    QMAKE_CXXFLAGS += -Wno-attributes
  }
}

*clang* {
  # http://llvm.org/bugs/show_bug.cgi?id=9182
  QMAKE_CXXFLAGS_WARN_ON += -Wno-overloaded-virtual
  # disable enormous amount of warnings about CGAL / boost / etc
  QMAKE_CXXFLAGS_WARN_ON += -Wno-unused-parameter
  QMAKE_CXXFLAGS_WARN_ON += -Wno-unused-variable
  QMAKE_CXXFLAGS_WARN_ON += -Wno-unused-function
  # gettext
  QMAKE_CXXFLAGS_WARN_ON += -Wno-format-security
  # might want to actually turn this on once in a while
  QMAKE_CXXFLAGS_WARN_ON += -Wno-sign-compare
}

skip-version-check {
  # force the use of outdated libraries
  DEFINES += OPENSCAD_SKIP_VERSION_CHECK
}

isEmpty(PKG_CONFIG):PKG_CONFIG = pkg-config

# Application configuration
CONFIG += c++std
CONFIG += cgal
CONFIG += opencsg
CONFIG += glew
CONFIG += boost
CONFIG += eigen
CONFIG += glib-2.0
CONFIG += harfbuzz
CONFIG += freetype
CONFIG += fontconfig
CONFIG += lib3mf
CONFIG += gettext
CONFIG += libxml2
CONFIG += libzip
CONFIG += hidapi
CONFIG += spnav
CONFIG += double-conversion
CONFIG += cairo

# Make experimental features available
experimental {
  DEFINES += ENABLE_EXPERIMENTAL
}

nogui {
  DEFINES += OPENSCAD_NOGUI
}

mdi {
  DEFINES += ENABLE_MDI
}

system("ccache -V >/dev/null 2>/dev/null") {
  CONFIG += ccache
  message("Using ccache")
}

include(common.pri)

# mingw has to come after other items so OBJECT_DIRS will work properly
CONFIG(mingw-cross-env)|CONFIG(mingw-cross-env-shared) {
  include(mingw-cross-env.pri)
}

RESOURCES = openscad.qrc

# Qt5 removed access to the QMAKE_UIC variable, the following
# way works for both Qt4 and Qt5
load(uic)
uic.commands += -tr q_

FORMS   += src/gui/MainWindow.ui \
           src/gui/ErrorLog.ui \
           src/gui/Preferences.ui \
           src/gui/OpenCSGWarningDialog.ui \
           src/gui/AboutDialog.ui \
           src/gui/FontListDialog.ui \
           src/gui/PrintInitDialog.ui \
           src/gui/ProgressWidget.ui \
           src/gui/launchingscreen.ui \
           src/gui/LibraryInfoDialog.ui \
           src/gui/Console.ui \
           src/parameter/ParameterWidget.ui \
           src/parameter/ParameterEntryWidget.ui \
           src/input/ButtonConfigWidget.ui \
           src/input/AxisConfigWidget.ui

# AST nodes
FLEXSOURCES += src/engine/lexer.l
BISONSOURCES += src/engine/parser.y

HEADERS += src/engine/AST.h \
           src/engine/ModuleInstantiation.h \
           src/engine/Package.h \
           src/engine/Assignment.h \
           src/engine/expression.h \
           src/engine/function.h \
           src/engine/module.h \
           src/engine/UserModule.h \

SOURCES += src/engine/AST.cc \
           src/engine/ModuleInstantiation.cc \
           src/engine/Assignment.cc \
           src/porters/export_pdf.cc \
           src/engine/expr.cc \
           src/engine/function.cc \
           src/engine/module.cc \
           src/engine/UserModule.cc \
           src/engine/annotation.cc

# Comment parser
FLEXSOURCES += src/engine/comment_lexer.l
BISONSOURCES += src/engine/comment_parser.y

HEADERS += src/gui/version_check.h \
           src/common/version_helper.h \
           src/gui/ProgressWidget.h \
           src/engine/parsersettings.h \
           src/renderer/renderer.h \
           src/settings.h \
           src/renderer/rendersettings.h \
           src/colormap.h \
           src/renderer/ThrownTogetherRenderer.h \
           src/engine/CGAL_OGL_Polyhedron.h \
           src/gui/QGLView.h \
           src/gui/GLView.h \
           src/gui/MainWindow.h \
           src/gui/tabmanager.h \
           src/gui/tabwidget.h \
           src/OpenSCADApp.h \
           src/gui/WindowManager.h \
           src/gui/initConfig.h \
           src/gui/Preferences.h \
           src/gui/SettingsWriter.h \
           src/gui/OpenCSGWarningDialog.h \
           src/gui/AboutDialog.h \
           src/gui/FontListDialog.h \
           src/gui/FontListTableView.h \
           src/engine/GroupModule.h \
           src/engine/FileModule.h \
           src/engine/StatCache.h \
           src/scadapi.h \
           src/engine/builtin.h \
           src/engine/calc.h \
           src/engine/context.h \
           src/engine/builtincontext.h \
           src/engine/modcontext.h \
           src/engine/evalcontext.h \
           src/engine/csgops.h \
           src/engine/CSGTreeNormalizer.h \
           src/engine/CSGTreeEvaluator.h \
           src/porters/dxfdata.h \
           src/porters/dxfdim.h \
           src/porters/export.h \
           src/engine/stackcheck.h \
           src/engine/exceptions.h \
           src/engine/grid.h \
           src/engine/math/hash.h \
           src/engine/localscope.h \
           src/engine/feature.h \
           src/engine/node.h \
           src/engine/csgnode.h \
           src/engine/offsetnode.h \
           src/engine/linearextrudenode.h \
           src/engine/rotateextrudenode.h \
           src/engine/projectionnode.h \
           src/engine/cgaladvnode.h \
           src/engine/importnode.h \
           src/porters/import.h \
           src/engine/transformnode.h \
           src/engine/colornode.h \
           src/engine/rendernode.h \
           src/engine/textnode.h \
           src/engine/TextModule.h \
           src/engine/TextModule.cc \
           src/gui/version.h \
           src/openscad.h \
           src/engine/handle_dep.h \
           src/engine/math/Geometry.h \
           src/engine/math/Polygon2d.h \
           src/engine/clipper-utils.h \
           src/engine/math/GeometryUtils.h \
           src/engine/math/polyset-utils.h \
           src/engine/math/polyset.h \
           src/common/printutils.h \
           src/common/fileutils.h \
           src/engine/value.h \
           src/engine/progress.h \
           src/gui/editor.h \
           src/engine/NodeVisitor.h \
           src/engine/math/state.h \
           src/engine/nodecache.h \
           src/engine/nodedumper.h \
           src/engine/ModuleCache.h \
           src/engine/GeometryCache.h \
           src/engine/GeometryEvaluator.h \
           src/engine/Tree.h \
           src/gui/DrawingCallback.h \
           src/gui/FreetypeRenderer.h \
           src/gui/FontCache.h \
           src/common/memory.h \
           src/engine/math/linalg.h \
           src/renderer/Camera.h \
           src/renderer/system-gl.h \
           src/common/boost-utils.h \
           src/gui/LibraryInfo.h \
           src/engine/RenderStatistic.h \
           src/engine/svg.h \
           src/gui/mouseselector.h \
           \
           src/renderer/OffscreenView.h \
           src/renderer/OffscreenContext.h \
           src/renderer/OffscreenContextAll.hpp \
           src/renderer/fbo.h \
           src/renderer/imageutils.h \
           src/renderer/system-gl.h \
           src/engine/CsgInfo.h \
           \
           src/gui/Dock.h \
           src/gui/Console.h \
           src/gui/ErrorLog.h \
           src/gui/AutoUpdater.h \
           src/gui/launchingscreen.h \
           src/gui/LibraryInfoDialog.h \
           \
           src/engine/comment.h\
           \
           src/parameter/ParameterWidget.h \
           src/parameter/parameterobject.h \
           src/parameter/parameterextractor.h \
           src/parameter/parametervirtualwidget.h \
           src/parameter/parameterspinbox.h \
           src/parameter/parametercombobox.h \
           src/parameter/parameterslider.h \
           src/parameter/parametercheckbox.h \
           src/parameter/parametertext.h \
           src/parameter/parametervector.h \
           src/parameter/groupwidget.h \
           src/parameter/parameterset.h \
           src/parameter/ignoreWheelWhenNotFocused.h \
           src/gui/QWordSearchField.h \
           src/gui/QSettingsCached.h \
           src/input/InputDriver.h \
           src/input/InputEventMapper.h \
           src/input/InputDriverManager.h \
           src/input/AxisConfigWidget.h \
           src/input/ButtonConfigWidget.h \
           src/input/WheelIgnorer.h

SOURCES += \
           src/libsvg/libsvg.cc \
           src/libsvg/circle.cc \
           src/libsvg/ellipse.cc \
           src/libsvg/line.cc \
           src/libsvg/text.cc \
           src/libsvg/tspan.cc \
           src/libsvg/data.cc \
           src/libsvg/polygon.cc \
           src/libsvg/polyline.cc \
           src/libsvg/rect.cc \
           src/libsvg/group.cc \
           src/libsvg/svgpage.cc \
           src/libsvg/path.cc \
           src/libsvg/shape.cc \
           src/libsvg/transformation.cc \
           src/libsvg/util.cc \
           \
           src/gui/version_check.cc

SOURCES += \
           src/gui/ProgressWidget.cc \
           src/engine/math/linalg.cc \
           src/renderer/Camera.cc \
           src/engine/handle_dep.cc \
           src/engine/value.cc \
           src/engine/math/degree_trig.cc \
           src/engine/func.cc \
           src/engine/localscope.cc \
           src/engine/feature.cc \
           src/engine/node.cc \
           src/engine/context.cc \
           src/engine/builtincontext.cc \
           src/engine/modcontext.cc \
           src/engine/evalcontext.cc \
           src/engine/csgnode.cc \
           src/engine/CSGTreeNormalizer.cc \
           src/engine/CSGTreeEvaluator.cc \
           src/engine/math/Geometry.cc \
           src/engine/math/Polygon2d.cc \
           src/engine/clipper-utils.cc \
           src/engine/math/polyset-utils.cc \
           src/engine/math/GeometryUtils.cc \
           src/engine/math/polyset.cc \
           src/engine/csgops.cc \
           src/engine/transform.cc \
           src/engine/color.cc \
           src/engine/primitives.cc \
           src/engine/projection.cc \
           src/engine/cgaladv.cc \
           src/engine/surface.cc \
           src/engine/control.cc \
           src/renderer/render.cc \
           src/engine/TextModule.cc \
           src/engine/text.cc \
           src/porters/dxfdata.cc \
           src/porters/dxfdim.cc \
           src/engine/offset.cc \
           src/engine/linearextrude.cc \
           src/engine/rotateextrude.cc \
           src/common/printutils.cc \
           src/common/fileutils.cc \
           src/engine/progress.cc \
           src/engine/parsersettings.cc \
           src/common/boost-utils.cc \
           src/common/PlatformUtils.cc \
           src/gui/LibraryInfo.cc \
           src/engine/RenderStatistic.cc \
           \
           src/engine/nodedumper.cc \
           src/engine/NodeVisitor.cc \
           src/engine/GeometryEvaluator.cc \
           src/engine/ModuleCache.cc \
           src/engine/GeometryCache.cc \
           src/engine/Tree.cc \
	       src/gui/DrawingCallback.cc \
	       src/gui/FreetypeRenderer.cc \
	       src/gui/FontCache.cc \
           \
           src/settings.cc \
           src/renderer/rendersettings.cc \
           src/gui/initConfig.cc \
           src/gui/Preferences.cc \
           src/gui/SettingsWriter.cc \
           src/gui/OpenCSGWarningDialog.cc \
           src/gui/editor.cc \
           src/gui/GLView.cc \
           src/gui/QGLView.cc \
           src/gui/AutoUpdater.cc \
           \
           src/engine/math/hash.cc \
           src/engine/GroupModule.cc \
           src/engine/FileModule.cc \
           src/engine/StatCache.cc \
           src/scadapi.cc \
           src/engine/builtin.cc \
           src/engine/calc.cc \
           src/porters/export.cc \
           src/porters/export_stl.cc \
           src/porters/export_amf.cc \
           src/porters/export_3mf.cc \
           src/porters/export_off.cc \
           src/porters/export_dxf.cc \
           src/porters/export_svg.cc \
           src/porters/export_nef.cc \
           src/porters/export_png.cc \
           src/porters/import.cc \
           src/porters/import_stl.cc \
           src/porters/import_off.cc \
           src/porters/import_svg.cc \
           src/porters/import_amf.cc \
           src/porters/import_3mf.cc \
           src/renderer/renderer.cc \
           src/colormap.cc \
           src/renderer/ThrownTogetherRenderer.cc \
           src/engine/svg.cc \
           src/renderer/OffscreenView.cc \
           src/renderer/fbo.cc \
           src/renderer/system-gl.cc \
           src/renderer/imageutils.cc \
           \
           src/gui/version.cc \
           src/openscad.cc \
           src/gui/mainwin.cc \
           src/gui/tabmanager.cc \
           src/gui/tabwidget.cc \
           src/OpenSCADApp.cc \
           src/gui/WindowManager.cc \
           src/gui/UIUtils.cc \
           src/gui/Dock.cc \
           src/gui/Console.cc \
           src/gui/ErrorLog.cc \
           src/gui/FontListDialog.cc \
           src/gui/FontListTableView.cc \
           src/gui/launchingscreen.cc \
           src/gui/LibraryInfoDialog.cc\
           \
           src/engine/comment.cpp \
           src/gui/mouseselector.cc \
           \
           src/parameter/ParameterWidget.cc\
           src/parameter/parameterobject.cpp \
           src/parameter/parameterextractor.cpp \
           src/parameter/parameterspinbox.cpp \
           src/parameter/parametercombobox.cpp \
           src/parameter/parameterslider.cpp \
           src/parameter/parametercheckbox.cpp \
           src/parameter/parametertext.cpp \
           src/parameter/parametervector.cpp \
           src/parameter/groupwidget.cpp \
           src/parameter/parameterset.cpp \
           src/parameter/parametervirtualwidget.cpp \
           src/parameter/ignoreWheelWhenNotFocused.cpp \
           src/gui/QWordSearchField.cc\
           src/gui/QSettingsCached.cc \
           \
           src/input/InputDriver.cc \
           src/input/InputEventMapper.cc \
           src/input/InputDriverManager.cc \
           src/input/AxisConfigWidget.cc \
           src/input/ButtonConfigWidget.cc \
           src/input/WheelIgnorer.cc

# CGAL
HEADERS += src/ext/CGAL/OGL_helper.h \
           src/ext/CGAL/CGAL_workaround_Mark_bounded_volumes.h

# LodePNG
SOURCES += src/ext/lodepng/lodepng.cpp
HEADERS += src/ext/lodepng/lodepng.h
           
# ClipperLib
SOURCES += src/ext/polyclipping/clipper.cpp
HEADERS += src/ext/polyclipping/clipper.hpp

# libtess2
INCLUDEPATH += src/ext/libtess2/Include
SOURCES += src/ext/libtess2/Source/bucketalloc.c \
           src/ext/libtess2/Source/dict.c \
           src/ext/libtess2/Source/geom.c \
           src/ext/libtess2/Source/mesh.c \
           src/ext/libtess2/Source/priorityq.c \
           src/ext/libtess2/Source/sweep.c \
           src/ext/libtess2/Source/tess.c
HEADERS += src/ext/libtess2/Include/tesselator.h \
           src/ext/libtess2/Source/bucketalloc.h \
           src/ext/libtess2/Source/dict.h \
           src/ext/libtess2/Source/geom.h \
           src/ext/libtess2/Source/mesh.h \
           src/ext/libtess2/Source/priorityq.h \
           src/ext/libtess2/Source/sweep.h \
           src/ext/libtess2/Source/tess.h

has_qt5 {
  HEADERS += src/octoprint/Network.h src/octoprint/NetworkSignal.h src/octoprint/PrintService.h src/octoprint/OctoPrint.h src/gui/PrintInitDialog.h
  SOURCES += src/octoprint/PrintService.cc src/octoprint/OctoPrint.cc src/gui/PrintInitDialog.cc
}

has_qt5:unix:!macx {
  QT += dbus
  DEFINES += ENABLE_DBUS
  DBUS_ADAPTORS += org.openscad.OpenSCAD.xml
  DBUS_INTERFACES += org.openscad.OpenSCAD.xml

  HEADERS += src/input/DBusInputDriver.h
  SOURCES += src/input/DBusInputDriver.cc
}

linux: {
  DEFINES += ENABLE_JOYSTICK

  HEADERS += src/input/JoystickInputDriver.h
  SOURCES += src/input/JoystickInputDriver.cc
}

!lessThan(QT_MAJOR_VERSION, 5) {
  qtHaveModule(gamepad) {
    QT += gamepad
    DEFINES += ENABLE_QGAMEPAD
    HEADERS += src/input/QGamepadInputDriver.h
    SOURCES += src/input/QGamepadInputDriver.cc
  }
}

unix:!macx {
  SOURCES += src/renderer/imageutils-lodepng.cc
  SOURCES += src/posix/OffscreenContextGLX.cc
}
macx {
  SOURCES += src/osx/imageutils-macosx.cc
  OBJECTIVE_SOURCES += src/osx/OffscreenContextCGL.mm
}
win* {
  SOURCES += src/renderer/imageutils-lodepng.cc
  SOURCES += src/win/OffscreenContextWGL.cc
}

opencsg {
  HEADERS += src/renderer/OpenCSGRenderer.h
  SOURCES += src/renderer/OpenCSGRenderer.cc
}

cgal {
HEADERS += src/engine/cgal.h \
           src/engine/cgalutils.h \
           src/engine/Reindexer.h \
           src/engine/CGALCache.h \
           src/renderer/CGALRenderer.h \
           src/engine/CGAL_Nef_polyhedron.h \
           src/engine/cgalworker.h \
           src/engine/Polygon2d-CGAL.h

SOURCES += src/engine/cgalutils.cc \
           src/engine/cgalutils-applyops.cc \
           src/engine/cgalutils-project.cc \
           src/engine/cgalutils-tess.cc \
           src/engine/cgalutils-polyhedron.cc \
           src/engine/CGALCache.cc \
           src/renderer/CGALRenderer.cc \
           src/engine/CGAL_Nef_polyhedron.cc \
           src/engine/cgalworker.cc \
           src/engine/Polygon2d-CGAL.cc \
           src/porters/import_nef.cc
}

macx {
  HEADERS += src/osx/AppleEvents.h \
             src/osx/EventFilter.h \
             src/osx/CocoaUtils.h
  SOURCES += src/osx/AppleEvents.cc
  OBJECTIVE_SOURCES += src/osx/CocoaUtils.mm \
                       src/osx/PlatformUtils-mac.mm
}
unix:!macx {
  SOURCES += src/posix/PlatformUtils-posix.cc
}
win* {
  HEADERS += src/win/findversion.h
  SOURCES += src/win/PlatformUtils-win.cc
}

isEmpty(PREFIX):PREFIX = /usr/local

target.path = $$PREFIX/bin/
INSTALLS += target

# Run translation update scripts as last step after linking the target
QMAKE_POST_LINK += "'$$PWD/scripts/translation-make.sh'"

# Create install targets for the languages defined in LINGUAS
LINGUAS = $$cat(locale/LINGUAS)
LOCALE_PREFIX = "$$PREFIX/share/$${FULLNAME}/locale"
for(language, LINGUAS) {
  catalogdir = locale/$$language/LC_MESSAGES
  exists(locale/$${language}.po) {
    # Use .extra and copy manually as the source path might not exist,
    # e.g. on a clean checkout. In that case qmake would not create
    # the needed targets in the generated Makefile.
    translation_path = translation_$${language}.path
    translation_extra = translation_$${language}.extra
    translation_depends = translation_$${language}.depends
    $$translation_path = $$LOCALE_PREFIX/$$language/LC_MESSAGES/
    $$translation_extra = cp -f $${catalogdir}/openscad.mo \"\$(INSTALL_ROOT)$$LOCALE_PREFIX/$$language/LC_MESSAGES/openscad.mo\"
    $$translation_depends = locale/$${language}.po
    INSTALLS += translation_$$language
  }
}

examples.path = "$$PREFIX/share/$${FULLNAME}/examples/"
examples.files = examples/*
INSTALLS += examples

libraries.path = "$$PREFIX/share/$${FULLNAME}/libraries/"
libraries.files = libraries/*
INSTALLS += libraries

fonts.path = "$$PREFIX/share/$${FULLNAME}/fonts/"
fonts.files = fonts/*
INSTALLS += fonts

colorschemes.path = "$$PREFIX/share/$${FULLNAME}/color-schemes/"
colorschemes.files = color-schemes/*
INSTALLS += colorschemes

templates.path = "$$PREFIX/share/$${FULLNAME}/templates/"
templates.files = templates/*
INSTALLS += templates

applications.path = $$PREFIX/share/applications
applications.extra = mkdir -p \"\$(INSTALL_ROOT)$${applications.path}\" && cat icons/openscad.desktop | sed -e \"'s/^Icon=openscad/Icon=$${FULLNAME}/; s/^Exec=openscad/Exec=$${FULLNAME}/'\" > \"\$(INSTALL_ROOT)$${applications.path}/$${FULLNAME}.desktop\"
INSTALLS += applications

mimexml.path = $$PREFIX/share/mime/packages
mimexml.extra = cp -f icons/openscad.xml \"\$(INSTALL_ROOT)$${mimexml.path}/$${FULLNAME}.xml\"
INSTALLS += mimexml

appdata.path = $$PREFIX/share/metainfo
appdata.extra = mkdir -p \"\$(INSTALL_ROOT)$${appdata.path}\" && cat openscad.appdata.xml | sed -e \"'s/$${APPLICATIONID}/$${APPLICATIONID}$${SUFFIX}/; s/openscad.desktop/openscad$${SUFFIX}.desktop/; s/openscad.png/openscad$${SUFFIX}.png/'\" > \"\$(INSTALL_ROOT)$${appdata.path}/$${APPLICATIONID}$${SUFFIX}.appdata.xml\"
INSTALLS += appdata

icon48.path = $$PREFIX/share/icons/hicolor/48x48/apps
icon48.extra = test -f icons/$${FULLNAME}-48.png && cp -f icons/$${FULLNAME}-48.png \"\$(INSTALL_ROOT)$${icon48.path}/$${FULLNAME}.png\" || cp -f icons/openscad-48.png \"\$(INSTALL_ROOT)$${icon48.path}/$${FULLNAME}.png\"
icon64.path = $$PREFIX/share/icons/hicolor/64x64/apps
icon64.extra = test -f icons/$${FULLNAME}-64.png && cp -f icons/$${FULLNAME}-64.png \"\$(INSTALL_ROOT)$${icon64.path}/$${FULLNAME}.png\" || cp -f icons/openscad-64.png \"\$(INSTALL_ROOT)$${icon64.path}/$${FULLNAME}.png\"
icon128.path = $$PREFIX/share/icons/hicolor/128x128/apps
icon128.extra = test -f icons/$${FULLNAME}-128.png && cp -f icons/$${FULLNAME}-128.png \"\$(INSTALL_ROOT)$${icon128.path}/$${FULLNAME}.png\" || cp -f icons/openscad-128.png \"\$(INSTALL_ROOT)$${icon128.path}/$${FULLNAME}.png\"
icon256.path = $$PREFIX/share/icons/hicolor/256x256/apps
icon256.extra = test -f icons/$${FULLNAME}-256.png && cp -f icons/$${FULLNAME}-256.png \"\$(INSTALL_ROOT)$${icon256.path}/$${FULLNAME}.png\" || cp -f icons/openscad-256.png \"\$(INSTALL_ROOT)$${icon256.path}/$${FULLNAME}.png\"
icon512.path = $$PREFIX/share/icons/hicolor/512x512/apps
icon512.extra = test -f icons/$${FULLNAME}-512.png && cp -f icons/$${FULLNAME}-512.png \"\$(INSTALL_ROOT)$${icon512.path}/$${FULLNAME}.png\" || cp -f icons/openscad-512.png \"\$(INSTALL_ROOT)$${icon512.path}/$${FULLNAME}.png\"
INSTALLS += icon48 icon64 icon128 icon256 icon512

man.path = $$PREFIX/share/man/man1
man.extra = cp -f doc/openscad.1 \"\$(INSTALL_ROOT)$${man.path}/$${FULLNAME}.1\"
INSTALLS += man

info: {
    include(info.pri)
}

DISTFILES += \
    sounds/complete.wav
