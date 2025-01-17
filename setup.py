import os
import re
import sys
import sysconfig
import platform
import subprocess

from distutils.version import LooseVersion
from setuptools import setup, Extension, find_packages
from setuptools.command.build_ext import build_ext


class CMakeExtension(Extension):
    def __init__(self, name, sourcedir=''):
        Extension.__init__(self, name, sources=[])
        self.sourcedir = os.path.abspath(sourcedir)


class CMakeBuild(build_ext):
    def run(self):
        try:
            out = subprocess.check_output(['cmake', '--version'])
        except OSError:
            raise RuntimeError(
                "CMake must be installed to build the following extensions: " +
                ", ".join(e.name for e in self.extensions))

        if platform.system() == "Windows":
            cmake_version = LooseVersion(re.search(r'version\s*([\d.]+)',
                                         out.decode()).group(1))
            if cmake_version < '3.1.0':
                raise RuntimeError("CMake >= 3.1.0 is required on Windows")

        for ext in self.extensions:
            self.build_extension(ext)

    def build_extension(self, ext):
        extdir = os.path.abspath(
            os.path.join(
                os.path.dirname(self.get_ext_fullpath(ext.name)),
                ext.name
        ))
        
        cmake_args = ['-Wno-dev',
                      '-DCMAKE_LIBRARY_OUTPUT_DIRECTORY=' + extdir,
                      '-DCMAKE_SWIG_OUTDIR=' + extdir,
                      '-DWITH_PYTHON=ON',
                      '-DPython3_EXECUTABLE:FILEPATH=' + sys.executable,

                      # TODO: Still need this?
                      '-DPYTHON_EXECUTABLE=' + sys.executable]

        gtest_root = os.environ.get('GTEST_ROOT')
        if gtest_root:
            cmake_args += ["-DGTEST_ROOT=" + os.path.abspath(gtest_root)]

        cfg = 'Debug' if self.debug else 'Release'
        build_args = ['--config', cfg]

        if platform.system() == "Windows":
            cmake_args += ['-DCMAKE_LIBRARY_OUTPUT_DIRECTORY_{}={}'.format(
                cfg.upper(),
                extdir)]
            if sys.maxsize > 2**32:
                cmake_args += ['-A', 'x64']
            build_args += ['--', '/m']
        else:
            cmake_args += ['-DCMAKE_BUILD_TYPE=' + cfg]
            build_args += ['--', '-j2']

        cxx_flags = [
            os.environ.get('CXXFLAGS', ''),
            '-DVERSION_INFO=\\"{}\\"'.format(self.distribution.get_version())
        ]
        if gtest_root:
            g_inc = os.path.abspath(os.path.join(gtest_root, "googletest", "include"))
            cxx_flags += ['-I' + g_inc]

        env = os.environ.copy()
        env['CXXFLAGS'] = ' '.join(cxx_flags)

        if not os.path.exists(self.build_temp):
            os.makedirs(self.build_temp)
        subprocess.check_call(['cmake', ext.sourcedir] + cmake_args,
                              cwd=self.build_temp, env=env)
        subprocess.check_call(['cmake', '--build', '.'] + build_args,
                              cwd=self.build_temp)
        print()

with open(os.path.join(os.path.dirname(__file__), 'README.md')) as r_file:
    readme = r_file.read()

setup(
    name='s2-py',
    version='0.11.0',
    description='pip-able S2 Geometry Bindings',
    long_description=readme,
    author='Gabe Frangakis',
    license='Apache',
    packages=find_packages('lib'),
    # won't build if zip_safe
    zip_safe=False,
    package_dir={'': 'lib'},
    # add extension module
    ext_modules=[CMakeExtension('s2_py')],
    # add custom build_ext command
    cmdclass=dict(build_ext=CMakeBuild),
)
