import os
import sys
import warnings
import unittest

try:
    from setuptools import setup
except ImportError:
    from distutils.core import setup

try:
    from distutils.command.build_py import build_py_2to3 as build_py
except ImportError:
    from distutils.command.build_py import build_py

"""
https://packaging.python.org/guides/making-a-pypi-friendly-readme/
check the README.rst works on pypi as the
long_description with:
twine check dist/*
"""
long_description = open('README.rst').read()

cur_path, cur_script = os.path.split(sys.argv[0])
os.chdir(os.path.abspath(cur_path))

requires_that_fail_on_rtd = [
    'awscli'
]

install_requires = []

cur_dir = os.path.abspath(os.path.dirname(__file__))
with open(os.path.join(
        cur_dir, 'requirements.txt'), encoding='utf-8') as f:
    install_requires = f.read().split()

# if not on readthedocs.io or travis ci get all the pips:
if (os.getenv('READTHEDOCS', '') == ''
        and os.getenv('TRAVIS', '') == ''):
    install_requires = install_requires + requires_that_fail_on_rtd

if sys.version_info < (2, 7):
    warnings.warn(
        'Less than Python 2.7 is not supported.',
        DeprecationWarning)


def metalnetes_test_suite():
    test_loader = unittest.TestLoader()
    test_suite = test_loader.discover('tests', pattern='test_*.py')
    return test_suite


# Don't import analysis_engine module here, since deps may not be installed
sys.path.insert(
    0,
    os.path.join(
        os.path.dirname(__file__),
        'metalnetes'))

setup(
    name='metalnetes',
    cmdclass={'build_py': build_py},
    version='1.0.6',
    description=(
        'Tools for managing multiple kubernetes clusters on KVM '
        '(on 3 Centos 7 vms) running on a bare metal server '
        '(tested on Ubuntu 18.04)'
        ''),
    long_description=long_description,
    author='Jay Johnson',
    author_email='jay.p.h.johnson@gmail.com',
    url='https://github.com/jay-johnson/metalnetes',
    packages=[
        'metalnetes.log',
    ],
    package_data={},
    install_requires=install_requires,
    test_suite='setup.metalnetes_test_suite',
    tests_require=[
    ],
    scripts=[
    ],
    entry_points={
        'console_scripts': [
        ],
    },
    classifiers=[
        'Development Status :: 5 - Production/Stable',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: Apache Software License',
        'Operating System :: OS Independent',
        'Programming Language :: Python :: 2.7',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: Implementation :: PyPy',
        'Topic :: Software Development :: Libraries :: Python Modules',
    ])
