#!/usr/bin/env python

import os
import sys
import itertools

KEY_LIST = ['tile_mode', 'tile_size', 'node', 'branch']
PREFIX_DICT = dict(branch='BRANCH=', 
                   node='NODE=',
                   tile_mode='REPART_ENABLE_TILE_MODE=',
                   tile_size='TILE_SIZE=')

def parse_header(data):
    def parse_line(result, number, line):
        for key in KEY_LIST:
            prefix = PREFIX_DICT[key]
            if line.startswith(prefix):
                if key in result:
                    raise ValueError('duplicate key %s on line %s' % (key, number))
                else:
                    result[key] = line[len(prefix):]
                    return result
        raise ValueError("can not parse '%s' line number %s" % (line, number))
    result = {}
    for number in xrange(0, len(KEY_LIST)):
        result = parse_line(result, number, data.next())
    return data, result

def collect_header(result, header):
    for key in KEY_LIST:
        if key in result:
            if type(result[key]) == list:
                result[key] = set(result[key])
        else:
            result[key] = set()
        result[key].add(header[key])
    for key in KEY_LIST:
        result[key] = sorted(list(result[key]))
    return result
    

def parse_log(data):
    def is_test_result(items):
        return len(items) == 2
    def collect(result, items):
        test_name, test_result = items[0], items[1]
        result[test_name] = test_result
        return result
    data = itertools.imap(str.split, data)
    data = itertools.ifilter(is_test_result, data)
    return reduce(collect, data, {})

def collect_log(compound_header):
    def build(result, key_list=KEY_LIST):
        assert(len(key_list))
        key = key_list[0]
        for value in compound_header[key]:
            if not value in result:
                if len(key_list) > 1:
                    result[value] = build({}, key_list=key_list[1:])
                else:
                    result[value] = 'OK'
        return result
    def r(result, header, data):
        header_key_list = []
        for key in KEY_LIST:
            header_key_list.append(header[key])
        def assign(result, value, key_list=None):
            assert(len(key_list))
            key = key_list[0]
            if len(key_list) > 1:
                result[key] = assign(result[key], value, key_list=key_list[1:])
            else:
                result[key] = value
            return result
        for test_name in data:
            if not test_name in result:
                result[test_name] = build({})
        for test_name in data:
            result = assign(result, data[test_name], [test_name] + header_key_list)
        return result
    return r
        
def collect(file_name_list):
    header = {}
    data = {}
    for file_name in file_name_list:
        with open(file_name, 'r') as file:
            source = file.xreadlines()
            source = itertools.imap(str.rstrip, source)
            source = itertools.ifilter(len, source)
            source, current_header = parse_header(source)
            header[file_name] = current_header
            data[file_name] = parse_log(source)
    header_list = list(header[file_name] for file_name in file_name_list)
    compound_header = reduce(collect_header, header_list, {})
    cl = collect_log(compound_header)
    result = {}
    for file_name in file_name_list:
        result = cl(result, header[file_name], data[file_name])    
    return compound_header, result

def walk(header, action=None, initial=None):
    def do(actual, tail):
        if len(tail):
            head = tail[0]
            for value in header[head]:
                for result in do(action(actual, head, value), tail[1:]):
                    yield result
        else:
            yield actual
    return do(initial, KEY_LIST)
    
def print_header(header):
    def action(actual, key, value):
        return actual + ['%s=%s' % (key, value)]
    for item in zip(*list(walk(header, action=action, initial=[]))):
        print '\t'.join(['test_name'] + list(item))

def print_data(header, data):
    def action(actual, _, value):
        return actual[value]
    for test_name in sorted(data):
        result = walk(header, action=action, initial=data[test_name])
        print '\t'.join([test_name] + list(result))

if __name__ == '__main__':
    header, data = collect(sys.argv[1:])
    print_header(header)
    print_data(header, data)
