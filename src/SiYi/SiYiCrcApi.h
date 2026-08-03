#ifndef SIYICRCAPI_H
#define SIYICRCAPI_H

#include <QObject>
#include <QStringList>

class SiYiCrcApi : public QObject
{
    Q_OBJECT
public:
    SiYiCrcApi(QObject *parent = Q_NULLPTR);
    static quint32 calculateCrc32(const QByteArray &bytes);
};

#endif
