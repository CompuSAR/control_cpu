#pragma once

// Barriers
#include "memory.h"

#include <array>

#include <stddef.h>

template <typename T, size_t BufferSize = 1024>
class SPSC {
    std::array<T, BufferSize> _buffer;
    volatile size_t _consumerIndex = 0, _producerIndex = 0;

public:
    SPSC() = default;

    bool isEmpty() const {
        return _consumerIndex==_producerIndex;
    }

    bool isFull() const {
        return next(_producerIndex) == _consumerIndex;
    }

    bool consume(T &data) {
        if( isEmpty() )
            return false;

        data = _buffer[_consumerIndex];
        rwb();
        _consumerIndex = next(_consumerIndex);

        return true;
    }

    bool produce(const T &data) {
        if( isFull() )
            return false;

        _buffer[_producerIndex] = data;
        wwb();
        _producerIndex = next(_producerIndex);

        return true;
    }

private:
    static size_t next( size_t current ) {
        return (current+1) % BufferSize;
    }
};
