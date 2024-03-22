#pragma once

#include <memory.h>

#include <cstddef>

template <typename T, size_t BufferSize = 1024>
class P1C1 {
    T _buffer[BufferSize];
    unsigned _producerIndex = 0, _consumerIndex = 0;

public:

    bool isEmpty() const {
        return _producerIndex == _consumerIndex;
    }

    bool isFull() const {
        return next(_producerIndex) == _consumerIndex;
    }

    void produce(T value) {
        // Assume !isFull()
        _buffer[_producerIndex] = value;

        wwb();

        _producerIndex = next(_producerIndex);
    }

    T consume() {
        // Assume !isEmpty()
        T ret = _buffer[_consumerIndex];

        rwb();

        _consumerIndex = next(_consumerIndex);

        return ret;
    }

private:
    static unsigned next(unsigned current) {
        return (current+1) % BufferSize;
    }
};
