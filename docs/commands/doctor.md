# doctor.sh

`rnfmac doctor` — read-only health sweep across all groups.

## Overview

Meta: system doctor + profile check + brew diff, a read-only sweep across all
groups. Exit 0 healthy, 1 if any group reports drift/problems.
Version: 1.0
Author: Rohit Narayanan

## Index

* [execute](#execute)

### execute

Run `rnfmac doctor`: system doctor, profile check, and brew diff, all
read-only. Continues through all three even if one reports drift.

_Function has no arguments._

#### Variables set

* **PROBLEMS** (Set): to 1 if any group reported drift/problems.

