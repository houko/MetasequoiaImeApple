#pragma once

#include "core/scheme_type.h"

namespace metasequoia::mac
{
constexpr int NormalizeStoredInputScheme(int scheme)
{
    return scheme >= 0 && scheme <= 2 ? scheme : 0;
}

constexpr SchemeType EngineSchemeForStoredPreference(int scheme)
{
    switch (NormalizeStoredInputScheme(scheme))
    {
    case 1:
        return SchemeType::Shuangpin;
    case 2:
        return SchemeType::Wubi;
    default:
        return SchemeType::Quanpin;
    }
}
} // namespace metasequoia::mac
