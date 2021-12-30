/****************************************************************************
**
** Copyright (C) 2016 The Qt Company Ltd.
** Copyright (C) 2016 Intel Corporation.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the QtDBus module of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:LGPL$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** GNU Lesser General Public License Usage
** Alternatively, this file may be used under the terms of the GNU Lesser
** General Public License version 3 as published by the Free Software
** Foundation and appearing in the file LICENSE.LGPL3 included in the
** packaging of this file. Please review the following information to
** ensure the GNU Lesser General Public License version 3 requirements
** will be met: https://www.gnu.org/licenses/lgpl-3.0.html.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License version 2.0 or (at your option) the GNU General
** Public license version 3 or any later version approved by the KDE Free
** Qt Foundation. The licenses are as published by the Free Software
** Foundation and appearing in the file LICENSE.GPL2 and LICENSE.GPL3
** included in the packaging of this file. Please review the following
** information to ensure the GNU General Public License requirements will
** be met: https://www.gnu.org/licenses/gpl-2.0.html and
** https://www.gnu.org/licenses/gpl-3.0.html.
**
** $QT_END_LICENSE$
**
****************************************************************************/

#include "qdbusconnection.h"
#include "qdbusconnection_p.h"

#include <qdebug.h>
#include <qcoreapplication.h>
#include <qstringlist.h>
#include <qtimer.h>
#include <qthread.h>
#include <QtCore/private/qlocking_p.h>

#include "qdbusconnectioninterface.h"
#include "qdbuserror.h"
#include "qdbusmessage.h"
#include "qdbusmessage_p.h"
#include "qdbusinterface_p.h"
#include "qdbusutil_p.h"
#include "qdbusconnectionmanager_p.h"
#include "qdbuspendingcall_p.h"

#include "qdbusthreaddebug_p.h"

#include <algorithm>

#ifdef interface
#undef interface
#endif

#ifndef QT_NO_DBUS

QT_BEGIN_NAMESPACE

#ifdef Q_OS_WIN
static void preventDllUnload();
#endif

Q_GLOBAL_STATIC(QDBusConnectionManager, _q_manager)

QDBusConnectionPrivate *QDBusConnectionManager::busConnection(QDBusConnection::BusType type)
{
    static_assert(int(QDBusConnection::SessionBus) + int(QDBusConnection::SystemBus) == 1);
    Q_ASSERT(type == QDBusConnection::SessionBus || type == QDBusConnection::SystemBus);

    if (!qdbus_loadLibDBus())
        return nullptr;

    // we'll start in suspended delivery mode if we're in the main thread
    // (the event loop will resume delivery)
    bool suspendedDelivery = qApp && qApp->thread() == QThread::currentThread();

    const auto locker = qt_scoped_lock(defaultBusMutex);
    if (defaultBuses[type])
        return defaultBuses[type];

    QString name = QStringLiteral("qt_default_session_bus");
    if (type == QDBusConnection::SystemBus)
        name = QStringLiteral("qt_default_system_bus");
    return defaultBuses[type] = connectToBus(type, name, suspendedDelivery);
}

QDBusConnectionPrivate *QDBusConnectionManager::connection(const QString &name) const
{
    return connectionHash.value(name, nullptr);
}

void QDBusConnectionManager::removeConnection(const QString &name)
{
    QDBusConnectionPrivate *d = nullptr;
    d = connectionHash.take(name);
    if (d && !d->ref.deref())
        d->deleteLater();

    // Static objects may be keeping the connection open.
    // However, it is harmless to have outstanding references to a connection that is
    // closing as long as those references will be soon dropped without being used.

    // ### Output a warning if connections are being used after they have been removed.
}

QDBusConnectionManager::QDBusConnectionManager()
{
    connect(this, &QDBusConnectionManager::connectionRequested,
            this, &QDBusConnectionManager::executeConnectionRequest, Qt::BlockingQueuedConnection);
    connect(this, &QDBusConnectionManager::serverRequested,
            this, &QDBusConnectionManager::createServer, Qt::BlockingQueuedConnection);
    moveToThread(this);         // ugly, don't do this in other projects

#ifdef Q_OS_WIN
    // prevent the library from being unloaded on Windows. See comments in the function.
    preventDllUnload();
#endif
    defaultBuses[0] = defaultBuses[1] = nullptr;
    start();
}

QDBusConnectionManager::~QDBusConnectionManager()
{
    quit();
    wait();
}

QDBusConnectionManager* QDBusConnectionManager::instance()
{
    return _q_manager();
}

Q_DBUS_EXPORT void qDBusBindToApplication();
void qDBusBindToApplication()
{
}

void QDBusConnectionManager::setConnection(const QString &name, QDBusConnectionPrivate *c)
{
    connectionHash[name] = c;
    c->name = name;
}

void QDBusConnectionManager::run()
{
    exec();

    // cleanup:
    const auto locker = qt_scoped_lock(mutex);
    for (QHash<QString, QDBusConnectionPrivate *>::const_iterator it = connectionHash.constBegin();
         it != connectionHash.constEnd(); ++it) {
        QDBusConnectionPrivate *d = it.value();
        if (!d->ref.deref()) {
            delete d;
        } else {
            d->closeConnection();
            d->moveToThread(nullptr);     // allow it to be deleted in another thread
        }
    }
    connectionHash.clear();

    // allow deletion from any thread without warning
    moveToThread(nullptr);
}

QDBusConnectionPrivate *QDBusConnectionManager::connectToBus(QDBusConnection::BusType type, const QString &name,
                                                             bool suspendedDelivery)
{
    ConnectionRequestData data;
    data.type = ConnectionRequestData::ConnectToStandardBus;
    data.busType = type;
    data.name = &name;
    data.suspendedDelivery = suspendedDelivery;

    emit connectionRequested(&data);
    if (suspendedDelivery && data.result->connection) {
        data.result->ref.ref();
        QDBusConnectionDispatchEnabler *o = new QDBusConnectionDispatchEnabler(data.result);
        QTimer::singleShot(0, o, SLOT(execute()));
        o->moveToThread(qApp->thread());    // qApp was checked in the caller
    }
    return data.result;
}

QDBusConnectionPrivate *QDBusConnectionManager::connectToBus(const QString &address, const QString &name)
{
    ConnectionRequestData data;
    data.type = ConnectionRequestData::ConnectToBusByAddress;
    data.busAddress = &address;
    data.name = &name;
    data.suspendedDelivery = false;

    emit connectionRequested(&data);
    return data.result;
}

QDBusConnectionPrivate *QDBusConnectionManager::connectToPeer(const QString &address, const QString &name)
{
    ConnectionRequestData data;
    data.type = ConnectionRequestData::ConnectToPeerByAddress;
    data.busAddress = &address;
    data.name = &name;
    data.suspendedDelivery = false;

    emit connectionRequested(&data);
    return data.result;
}

void QDBusConnectionManager::executeConnectionRequest(QDBusConnectionManager::ConnectionRequestData *data)
{
    const auto locker = qt_scoped_lock(mutex);
    const QString &name = *data->name;
    QDBusConnectionPrivate *&d = data->result;

    // check if the connection exists by name
    d = connection(name);
    if (d || name.isEmpty())
        return;

    d = new QDBusConnectionPrivate;
    DBusConnection *c = nullptr;
    QDBusErrorInternal error;
    switch (data->type) {
    case ConnectionRequestData::ConnectToStandardBus:
        switch (data->busType) {
        case QDBusConnection::SystemBus:
            c = q_dbus_bus_get_private(DBUS_BUS_SYSTEM, error);
            break;
        case QDBusConnection::SessionBus:
            c = q_dbus_bus_get_private(DBUS_BUS_SESSION, error);
            break;
        case QDBusConnection::ActivationBus:
            c = q_dbus_bus_get_private(DBUS_BUS_STARTER, error);
            break;
        }
        break;

    case ConnectionRequestData::ConnectToBusByAddress:
    case ConnectionRequestData::ConnectToPeerByAddress:
        c = q_dbus_connection_open_private(data->busAddress->toUtf8().constData(), error);
        if (c && data->type == ConnectionRequestData::ConnectToBusByAddress) {
            // register on the bus
            if (!q_dbus_bus_register(c, error)) {
                q_dbus_connection_unref(c);
                c = nullptr;
            }
        }
        break;
    }

    setConnection(name, d);
    if (data->type == ConnectionRequestData::ConnectToPeerByAddress) {
        d->setPeer(c, error);
    } else {
        // create the bus service
        // will lock in QDBusConnectionPrivate::connectRelay()
        d->setConnection(c, error);
        d->createBusService();
        if (c && data->suspendedDelivery)
            d->setDispatchEnabled(false);
    }
}

void QDBusConnectionManager::createServer(const QString &address, void *server)
{
    QDBusErrorInternal error;
    QDBusConnectionPrivate *d = new QDBusConnectionPrivate;
    d->setServer(static_cast<QDBusServer *>(server),
                 q_dbus_server_listen(address.toUtf8().constData(), error), error);
}

/*!
    \class QDBusConnection
    \inmodule QtDBus
    \since 4.2

    \brief The QDBusConnection class represents a connection to the D-Bus bus daemon.

    This class is the initial point in a D-Bus session. Using it, you
    can get access to remote objects, interfaces; connect remote
    signals to your object's slots; register objects, etc.

    D-Bus connections are created using the connectToBus() function,
    which opens a connection to the server daemon and does the initial
    handshaking, associating that connection with a name. Further
    attempts to connect using the same name will return the same
    connection.

    The connection is then torn down using the disconnectFromBus()
    function.

    Once disconnected, calling connectToBus() will not reestablish a
    connection, you must create a new QDBusConnection instance.

    As a convenience for the two most common connection types, the
    sessionBus() and systemBus() functions return open connections to
    the session server daemon and the system server daemon,
    respectively. Those connections are opened when first used and are
    closed when the QCoreApplication destructor is run.

    D-Bus also supports peer-to-peer connections, without the need for
    a bus server daemon. Using this facility, two applications can
    talk to each other and exchange messages. This can be achieved by
    passing an address to connectToBus() function, which was opened by
    another D-Bus application using QDBusServer.
*/

/*!
    \enum QDBusConnection::BusType
    Specifies the type of the bus connection. The valid bus types are:

    \value SessionBus           the session bus, associated with the running desktop session
    \value SystemBus            the system bus, used to communicate with system-wide processes
    \value ActivationBus        the activation bus, the "alias" for the bus that started the
                                service

    On the Session Bus, one can find other applications by the same user that are sharing the same
    desktop session (hence the name). On the System Bus, however, processes shared for the whole
    system are usually found.
*/

/*!
    \enum QDBusConnection::RegisterOption
    Specifies the options for registering objects with the connection. The possible values are:

    \value ExportAdaptors                       export the contents of adaptors found in this object

    \value ExportScriptableSlots                export this object's scriptable slots
    \value ExportScriptableSignals              export this object's scriptable signals
    \value ExportScriptableProperties           export this object's scriptable properties
    \value ExportScriptableInvokables           export this object's scriptable invokables
    \value ExportScriptableContents             shorthand form for ExportScriptableSlots |
                                                ExportScriptableSignals |
                                                ExportScriptableProperties

    \value ExportNonScriptableSlots             export this object's non-scriptable slots
    \value ExportNonScriptableSignals           export this object's non-scriptable signals
    \value ExportNonScriptableProperties        export this object's non-scriptable properties
    \value ExportNonScriptableInvokables        export this object's non-scriptable invokables
    \value ExportNonScriptableContents          shorthand form for ExportNonScriptableSlots |
                                                ExportNonScriptableSignals |
                                                ExportNonScriptableProperties

    \value ExportAllSlots                       export all of this object's slots
    \value ExportAllSignals                     export all of this object's signals
    \value ExportAllProperties                  export all of this object's properties
    \value ExportAllInvokables                  export all of this object's invokables
    \value ExportAllContents                    export all of this object's contents
    \value ExportChildObjects                   export this object's child objects

    \sa registerObject(), QDBusAbstractAdaptor, {usingadaptors.html}{Using adaptors}
*/

/*!
    \internal
    \since 4.8
    \enum QDBusConnection::VirtualObjectRegisterOption
    Specifies the options for registering virtual objects with the connection. The possible values are:

    \value SingleNode                           register a virtual object to handle one path only
    \value SubPath                              register a virtual object so that it handles all sub paths

    \sa registerVirtualObject(), QDBusVirtualObject
*/

/*!
    \enum QDBusConnection::UnregisterMode
    The mode for unregistering an object path:

    \value UnregisterNode       unregister this node only: do not unregister child objects
    \value UnregisterTree       unregister this node and all its sub-tree

    Note, however, if this object was registered with the ExportChildObjects option, UnregisterNode
    will unregister the child objects too.
*/

/*!
    \since 4.8
    \enum QDBusConnection::ConnectionCapability

    This enum describes the available capabilities for a D-Bus connection.

    \value UnixFileDescriptorPassing        enables passing of Unix file descriptors to other processes
                                            (see QDBusUnixFileDescriptor)

    \sa connectionCapabilities()
*/

/*!
    Creates a QDBusConnection object attached to the connection with name \a name.

    This does not open the connection. You have to call connectToBus() to open it.
*/
QDBusConnection::QDBusConnection(const QString &name)
{
    if (name.isEmpty() || _q_manager.isDestroyed()) {
        d = nullptr;
    } else {
        const auto locker = qt_scoped_lock(_q_manager()->mutex);
        d = _q_manager()->connection(name);
        if (d)
            d->ref.ref();
    }
}

/*!
    Creates a copy of the \a other connection.
*/
QDBusConnection::QDBusConnection(const QDBusConnection &other)
{
    d = other.d;
    if (d)
        d->ref.ref();
}

/*!
  \internal
   Creates a connection object with the given \a dd as private object.
*/
QDBusConnection::QDBusConnection(QDBusConnectionPrivate *dd)
{
    d = dd;
    if (d)
        d->ref.ref();
}

/*!
    Disposes of this object. This does not close the connection: you
    have to call disconnectFromBus() to do that.
*/
QDBusConnection::~QDBusConnection()
{
    if (d && !d->ref.deref())
        d->deleteLater();
}

/*!
    Creates a copy of the connection \a other in this object. Note
    that the connection this object referenced before the copy, is not
    spontaneously disconnected.

    \sa disconnectFromBus()
*/
QDBusConnection &QDBusConnection::operator=(const QDBusConnection &other)
{
    if (other.d)
        other.d->ref.ref();
    if (d && !d->ref.deref())
        d->deleteLater();
    d = other.d;
    return *this;
}

/*!
    Opens a connection of type \a type to one of the known busses and
    associate with it the connection name \a name. Returns a
    QDBusConnection object associated with that connection.
*/
QDBusConnection QDBusConnection::connectToBus(BusType type, const QString &name)
{
    if (_q_manager.isDestroyed() || !qdbus_loadLibDBus()) {
        QDBusConnectionPrivate *d = nullptr;
        return QDBusConnection(d);
    }
    return QDBusConnection(_q_manager()->connectToBus(type, name, false));
}

/*!
    Opens a connection to a private bus on address \a address and associate with it the
    connection name \a name. Returns a QDBusConnection object associated with that connection.
*/
QDBusConnection QDBusConnection::connectToBus(const QString &address,
                                              const QString &name)
{
    if (_q_manager.isDestroyed() || !qdbus_loadLibDBus()) {
        QDBusConnectionPrivate *d = nullptr;
        return QDBusConnection(d);
    }
    return QDBusConnection(_q_manager()->connectToBus(address, name));
}
/*!
    \since 4.8

    Opens a peer-to-peer connection on address \a address and associate with it the
    connection name \a name. Returns a QDBusConnection object associated with that connection.
*/
QDBusConnection QDBusConnection::connectToPeer(const QString &address,
                                               const QString &name)
{
    if (_q_manager.isDestroyed() || !qdbus_loadLibDBus()) {
        QDBusConnectionPrivate *d = nullptr;
        return QDBusConnection(d);
    }
    return QDBusConnection(_q_manager()->connectToPeer(address, name));
}

/*!
    Closes the bus connection of name \a name.

    Note that if there are still QDBusConnection objects associated
    with the same connection, the connection will not be closed until
    all references are dropped. However, no further references can be
    created using the QDBusConnection constructor.
*/
void QDBusConnection::disconnectFromBus(const QString &name)
{
    if (_q_manager()) {
        const auto locker = qt_scoped_lock(_q_manager()->mutex);
        QDBusConnectionPrivate *d = _q_manager()->connection(name);
        if (d && d->mode != QDBusConnectionPrivate::ClientMode)
            return;
        _q_manager()->removeConnection(name);
    }
}

/*!
    \since 4.8

    Closes the peer connection of name \a name.

    Note that if there are still QDBusConnection objects associated
    with the same connection, the connection will not be closed until
    all references are dropped. However, no further references can be
    created using the QDBusConnection constructor.
*/
void QDBusConnection::disconnectFromPeer(const QString &name)
{
    if (_q_manager()) {
        const auto locker = qt_scoped_lock(_q_manager()->mutex);
        QDBusConnectionPrivate *d = _q_manager()->connection(name);
        if (d && d->mode != QDBusConnectionPrivate::PeerMode)
            return;
        _q_manager()->removeConnection(name);
    }
}

/*!
    Sends the \a message over this connection, without waiting for a
    reply. This is suitable for errors, signals, and return values as
    well as calls whose return values are not necessary.

    Returns \c true if the message was queued successfully, false otherwise.
*/
bool QDBusConnection::send(const QDBusMessage &message) const
{
    if (!d || !d->connection) {
        QDBusError err = QDBusError(QDBusError::Disconnected,
                                    QDBusUtil::disconnectedErrorMessage());
        if (d)
            d->lastError = err;
        return false;
    }
    return d->send(message);
}

/*!
    Sends the \a message over this connection and returns immediately.
    When the reply is received, the method \a returnMethod is called in
    the \a receiver object. If an error occurs, the method \a errorMethod
    will be called instead.

    If no reply is received within \a timeout milliseconds, an automatic
    error will be delivered indicating the expiration of the call.
    The default \a timeout is -1, which will be replaced with an
    implementation-defined value that is suitable for inter-process
    communications (generally, 25 seconds).

    This function is suitable for method calls only. It is guaranteed
    that the slot will be called exactly once with the reply, as long
    as the parameter types match and no error occurs.

    Returns \c true if the message was sent, or false if the message could
    not be sent.
*/
bool QDBusConnection::callWithCallback(const QDBusMessage &message, QObject *receiver,
                                       const char *returnMethod, const char *errorMethod,
                                       int timeout) const
{
    if (!d || !d->connection) {
        QDBusError err = QDBusError(QDBusError::Disconnected,
                                    QDBusUtil::disconnectedErrorMessage());
        if (d)
            d->lastError = err;
        return false;
    }
    return d->sendWithReplyAsync(message, receiver, returnMethod, errorMethod, timeout) != nullptr;
}

/*!
    \overload
    \deprecated
    Sends the \a message over this connection and returns immediately.
    When the reply is received, the method \a returnMethod is called in
    the \a receiver object.

    This function is suitable for method calls only. It is guaranteed
    that the slot will be called exactly once with the reply, as long
    as the parameter types match and no error occurs.

    This function is dangerous because it cannot report errors, including
    the expiration of the timeout.

    Returns \c true if the message was sent, or false if the message could
    not be sent.
*/
bool QDBusConnection::callWithCallback(const QDBusMessage &message, QObject *receiver,
                                       const char *returnMethod, int timeout) const
{
    return callWithCallback(message, receiver, returnMethod, nullptr, timeout);
}

/*!
    Sends the \a message over this connection and blocks, waiting for
    a reply, for at most \a timeout milliseconds. This function is
    suitable for method calls only. It returns the reply message as
    its return value, which will be either of type
    QDBusMessage::ReplyMessage or QDBusMessage::ErrorMessage.

    If no reply is received within \a timeout milliseconds, an automatic
    error will be delivered indicating the expiration of the call.
    The default \a timeout is -1, which will be replaced with an
    implementation-defined value that is suitable for inter-process
    communications (generally, 25 seconds).

    See the QDBusInterface::call() function for a more friendly way
    of placing calls.

    \warning If \a mode is QDBus::BlockWithGui, this function will
             reenter the Qt event loop in order to wait for the
             reply. During the wait, it may deliver signals and other
             method calls to your application. Therefore, it must be
             prepared to handle a reentrancy whenever a call is
             placed with call().
*/
QDBusMessage QDBusConnection::call(const QDBusMessage &message, QDBus::CallMode mode, int timeout) const
{
    if (!d || !d->connection) {
        QDBusError err = QDBusError(QDBusError::Disconnected,
                                    QDBusUtil::disconnectedErrorMessage());
        if (d)
            d->lastError = err;

        return QDBusMessage::createError(err);
    }

    if (mode != QDBus::NoBlock)
        return d->sendWithReply(message, mode, timeout);

    d->send(message);
    QDBusMessage retval;
    retval << QVariant(); // add one argument (to avoid .at(0) problems)
    return retval;
}

/*!
    \since 4.5
    Sends the \a message over this connection and returns
    immediately. This function is suitable for method calls only. It
    returns an object of type QDBusPendingCall which can be used to
    track the status of the reply.

    If no reply is received within \a timeout milliseconds, an automatic
    error will be delivered indicating the expiration of the call. The
    default \a timeout is -1, which will be replaced with an
    implementation-defined value that is suitable for inter-process
    communications (generally, 25 seconds). This timeout is also the
    upper limit for waiting in QDBusPendingCall::waitForFinished().

    See the QDBusInterface::asyncCall() function for a more friendly way
    of placing calls.
*/
QDBusPendingCall QDBusConnection::asyncCall(const QDBusMessage &message, int timeout) const
{
    if (!d || !d->connection) {
        return QDBusPendingCall(nullptr); // null pointer -> disconnected
    }

    QDBusPendingCallPrivate *priv = d->sendWithReplyAsync(message, nullptr, nullptr, nullptr, timeout);
    return QDBusPendingCall(priv);
}

/*!
    Connects the signal specified by the \a service, \a path, \a interface and \a name parameters to
    the slot \a slot in object \a receiver. The arguments \a service and \a path can be empty,
    denoting a connection to any signal of the (\a interface, \a name) pair, from any remote
    application.

    Returns \c true if the connection was successful.

    \warning The signal will only be delivered to the slot if the parameters match. This verification
             can be done only when the signal is received, not at connection time.
*/
bool QDBusConnection::connect(const QString &service, const QString &path, const QString& interface,
                              const QString &name, QObject *receiver, const char *slot)
{
    return connect(service, path, interface, name, QStringList(), QString(), receiver, slot);
}

/*!
    \overload

    Connects the signal to the slot \a slot in object \a
    receiver. Unlike the previous connect() overload, this function
    allows one to specify the parameter signature to be connected
    using the \a signature variable. The function will then verify
    that this signature can be delivered to the slot specified by \a
    slot and return false otherwise.

    Returns \c true if the connection was successful.

    \note This function verifies that the signal signature matches the
          slot's parameters, but it does not verify that the actual
          signal exists with the given signature in the remote
          service.
*/
bool QDBusConnection::connect(const QString &service, const QString &path, const QString& interface,
                              const QString &name, const QString &signature,
                              QObject *receiver, const char *slot)
{
    return connect(service, path, interface, name, QStringList(), signature, receiver, slot);
}

/*!
    \overload
    \since 4.6

    Connects the signal to the slot \a slot in object \a
    receiver. Unlike the previous connect() overload, this function
    allows one to specify the parameter signature to be connected
    using the \a signature variable. The function will then verify
    that this signature can be delivered to the slot specified by \a
    slot and return false otherwise.

    The \a argumentMatch parameter lists the string parameters to be matched,
    in sequential order. Note that, to match an empty string, you need to
    pass a QString that is empty but not null (i.e., QString("")). A null
    QString skips matching at that position.

    Returns \c true if the connection was successful.

    \note This function verifies that the signal signature matches the
          slot's parameters, but it does not verify that the actual
          signal exists with the given signature in the remote
          service.
*/
bool QDBusConnection::connect(const QString &service, const QString &path, const QString& interface,
                              const QString &name, const QStringList &argumentMatch, const QString &signature,
                              QObject *receiver, const char *slot)
{

    if (!receiver || !slot || !d || !d->connection)
        return false;
    if (interface.isEmpty() && name.isEmpty())
        return false;
    if (!interface.isEmpty() && !QDBusUtil::isValidInterfaceName(interface)) {
#ifndef QT_NO_DEBUG
        qWarning("QDBusConnection::connect: interface name '%s' is not valid", interface.toLatin1().constData());
#endif
        return false;
    }
    if (!service.isEmpty() && !QDBusUtil::isValidBusName(service)) {
#ifndef QT_NO_DEBUG
        qWarning("QDBusConnection::connect: service name '%s' is not valid", service.toLatin1().constData());
#endif
        return false;
    }
    if (!path.isEmpty() && !QDBusUtil::isValidObjectPath(path)) {
#ifndef QT_NO_DEBUG
        qWarning("QDBusConnection::connect: object path '%s' is not valid", path.toLatin1().constData());
#endif
        return false;
    }

    return d->connectSignal(service, path, interface, name, argumentMatch, signature, receiver, slot);
}

/*!
    Disconnects the signal specified by the \a service, \a path, \a interface
    and \a name parameters from the slot \a slot in object \a receiver. The
    arguments must be the same as passed to the connect() function.

    Returns \c true if the disconnection was successful.
*/
bool QDBusConnection::disconnect(const QString &service, const QString &path, const QString &interface,
                                 const QString &name, QObject *receiver, const char *slot)
{
    return disconnect(service, path, interface, name, QStringList(), QString(), receiver, slot);
}

/*!
    \overload

    Disconnects the signal specified by the \a service, \a path, \a
    interface, \a name, and \a signature parameters from the slot \a slot in
    object \a receiver. The arguments must be the same as passed to the
    connect() function.

    Returns \c true if the disconnection was successful.
*/
bool QDBusConnection::disconnect(const QString &service, const QString &path, const QString& interface,
                                 const QString &name, const QString &signature,
                                 QObject *receiver, const char *slot)
{
    return disconnect(service, path, interface, name, QStringList(), signature, receiver, slot);
}

/*!
    \overload
    \since 4.6

    Disconnects the signal specified by the \a service, \a path, \a
    interface, \a name, \a argumentMatch, and \a signature parameters from
    the slot \a slot in object \a receiver. The arguments must be the same as
    passed to the connect() function.

    Returns \c true if the disconnection was successful.
*/
bool QDBusConnection::disconnect(const QString &service, const QString &path, const QString& interface,
                                 const QString &name, const QStringList &argumentMatch, const QString &signature,
                                 QObject *receiver, const char *slot)
{
    if (!receiver || !slot || !d || !d->connection)
        return false;
    if (!interface.isEmpty() && !QDBusUtil::isValidInterfaceName(interface))
        return false;
    if (interface.isEmpty() && name.isEmpty())
        return false;

    return d->disconnectSignal(service, path, interface, name, argumentMatch, signature, receiver, slot);
}

/*!
    Registers the object \a object at path \a path and returns \c true if
    the registration was successful. The \a options parameter
    specifies how much of the object \a object will be exposed through
    D-Bus.

    This function does not replace existing objects: if there is already an object registered at
    path \a path, this function will return false. Use unregisterObject() to unregister it first.

    The ExportChildObjects flag exports child objects on D-Bus based on the
    path of the registered objects and the QObject::objectName of the child.
    Therefore, it is important for the child object to have an object name.

    You cannot register an object as a child object of an object that
    was registered with ExportChildObjects.
*/
bool QDBusConnection::registerObject(const QString &path, QObject *object, RegisterOptions options)
{
   return registerObject(path, QString(), object, options);
}

/*!
    \overload
    \since 5.5

    Registers the object \a object at path \a path with interface name \a interface
    and returns \c true if the registration was successful. The \a options parameter
    specifies how much of the object \a object will be exposed through
    D-Bus.

    This function does not replace existing objects: if there is already an object registered at
    path \a path, this function will return false. Use unregisterObject() to unregister it first.

    The ExportChildObjects flag exports child objects on D-Bus based on the
    path of the registered objects and the QObject::objectName of the child.
    Therefore, it is important for the child object to have an object name.

    You cannot register an object as a child object of an object that
    was registered with ExportChildObjects.
*/
bool QDBusConnection::registerObject(const QString &path, const QString &interface, QObject *object, RegisterOptions options)
{
    Q_ASSERT_X(QDBusUtil::isValidObjectPath(path), "QDBusConnection::registerObject",
               "Invalid object path given");
    if (!d || !d->connection || !object || !options || !QDBusUtil::isValidObjectPath(path))
        return false;

    auto pathComponents = QStringView{path}.split(QLatin1Char('/'));
    if (pathComponents.constLast().isEmpty())
        pathComponents.removeLast();
    QDBusWriteLocker locker(RegisterObjectAction, d);

    // lower-bound search for where this object should enter in the tree
    QDBusConnectionPrivate::ObjectTreeNode::DataList::Iterator node = &d->rootNode;
    int i = 1;
    while (node) {
        if (pathComponents.count() == i) {
            // this node exists
            // consider it free if there's no object here and the user is not trying to
            // replace the object sub-tree
            if (node->obj)
                return false;

            if (options & QDBusConnectionPrivate::VirtualObject) {
                if (options & SubPath && !node->children.isEmpty())
                    return false;
            } else {
                if ((options & ExportChildObjects && !node->children.isEmpty()))
                    return false;
            }
            // we can add the object here
            node->obj = object;
            node->flags = options;
            node->interfaceName = interface;

            d->registerObject(node);
            //qDebug("REGISTERED FOR %s", path.toLocal8Bit().constData());
            return true;
        }

        // if a virtual object occupies this path, return false
        if (node->obj && (node->flags & QDBusConnectionPrivate::VirtualObject) && (node->flags & QDBusConnection::SubPath)) {
            //qDebug("Cannot register object at %s because QDBusVirtualObject handles all sub-paths.",
            //       qPrintable(path));
            return false;
        }

        // find the position where we'd insert the node
        QDBusConnectionPrivate::ObjectTreeNode::DataList::Iterator it =
            std::lower_bound(node->children.begin(), node->children.end(), pathComponents.at(i));
        if (it != node->children.end() && it->name == pathComponents.at(i)) {
            // match: this node exists
            node = it;

            // are we allowed to go deeper?
            if (node->flags & ExportChildObjects) {
                // we're not
                //qDebug("Cannot register object at %s because %s exports its own child objects",
                //       qPrintable(path), qPrintable(pathComponents.at(i)));
                return false;
            }
        } else {
            // add entry
            node = node->children.insert(it, pathComponents.at(i).toString());
        }

        // iterate
        ++i;
    }

    Q_ASSERT_X(false, "QDBusConnection::registerObject", "The impossible happened");
    return false;
}

/*!
    \internal
    \since 4.8
    Registers a QDBusTreeNode for a path. It can handle a path including all child paths, thus
    handling multiple DBus nodes.

    To unregister a QDBusTreeNode use the unregisterObject() function with its path.
*/
bool QDBusConnection::registerVirtualObject(const QString &path, QDBusVirtualObject *treeNode,
                      VirtualObjectRegisterOption options)
{
    int opts = options | QDBusConnectionPrivate::VirtualObject;
    return registerObject(path, (QObject*) treeNode, (RegisterOptions) opts);
}

/*!
    Unregisters an object that was registered with the registerObject() at the object path given by
    \a path and, if \a mode is QDBusConnection::UnregisterTree, all of its sub-objects too.

    Note that you cannot unregister objects that were not registered with registerObject().
*/
void QDBusConnection::unregisterObject(const QString &path, UnregisterMode mode)
{
    if (!d || !d->connection || !QDBusUtil::isValidObjectPath(path))
        return;

    QDBusWriteLocker locker(UnregisterObjectAction, d);
    d->unregisterObject(path, mode);
}

/*!
    Return the object that was registered with the registerObject() at the object path given by
    \a path.
*/
QObject *QDBusConnection::objectRegisteredAt(const QString &path) const
{
    Q_ASSERT_X(QDBusUtil::isValidObjectPath(path), "QDBusConnection::registeredObject",
               "Invalid object path given");
    if (!d || !d->connection || !QDBusUtil::isValidObjectPath(path))
        return nullptr;

    auto pathComponents = QStringView{path}.split(QLatin1Char('/'));
    if (pathComponents.constLast().isEmpty())
        pathComponents.removeLast();

    // lower-bound search for where this object should enter in the tree
    QDBusReadLocker lock(ObjectRegisteredAtAction, d);
    const QDBusConnectionPrivate::ObjectTreeNode *node = &d->rootNode;

    int i = 1;
    while (node) {
        if (pathComponents.count() == i)
            return node->obj;
        if ((node->flags & QDBusConnectionPrivate::VirtualObject) && (node->flags & QDBusConnection::SubPath))
            return node->obj;

        QDBusConnectionPrivate::ObjectTreeNode::DataList::ConstIterator it =
            std::lower_bound(node->children.constBegin(), node->children.constEnd(), pathComponents.at(i));
        if (it == node->children.constEnd() || it->name != pathComponents.at(i))
            break;              // node not found

        node = it;
        ++i;
    }
    return nullptr;
}



/*!
    Returns a QDBusConnectionInterface object that represents the
    D-Bus server interface on this connection.
*/
QDBusConnectionInterface *QDBusConnection::interface() const
{
    if (!d || d->mode != QDBusConnectionPrivate::ClientMode)
        return nullptr;
    return d->busService;
}

/*!
    \internal
    \since 4.8

    Returns the internal, implementation-defined pointer for this
    connection. Currently, this returns a DBusConnection* pointer,
    without changing the reference count. It is the responsibility of
    the caller to call dbus_connection_ref if it wants to store the
    pointer.
*/
void *QDBusConnection::internalPointer() const
{
    return d ? d->connection : nullptr;
}

/*!
    Returns \c true if this QDBusConnection object is connected.
*/
bool QDBusConnection::isConnected() const
{
    return d && d->connection && q_dbus_connection_get_is_connected(d->connection);
}

/*!
    Returns the last error that happened in this connection.

    This function is provided for low-level code. If you're using
    QDBusInterface::call(), error codes are reported by its return
    value.

    \sa QDBusInterface, QDBusMessage
*/
QDBusError QDBusConnection::lastError() const
{
    return d ? d->lastError : QDBusError(QDBusError::Disconnected, QDBusUtil::disconnectedErrorMessage());
}

/*!
    Returns the unique connection name for this connection, if this QDBusConnection object is
    connected, or an empty QString otherwise.

    A Unique Connection Name is a string in the form ":x.xxx" (where x
    are decimal digits) that is assigned by the D-Bus server daemon
    upon connection. It uniquely identifies this client in the bus.

    This function returns an empty QString for peer-to-peer connections.
*/
QString QDBusConnection::baseService() const
{
    return d ? d->baseService : QString();
}

/*!
    \since 4.5

    Returns the connection name for this connection, as given as the
    name parameter to connectToBus().

    The connection name can be used to uniquely identify actual
    underlying connections to buses.  Copies made from a single
    connection will always implicitly share the underlying connection,
    and hence will have the same connection name.

    Inversely, two connections having different connection names will
    always either be connected to different buses, or have a different
    unique name (as returned by baseService()) on that bus.

    \sa connectToBus(), disconnectFromBus()
*/
QString QDBusConnection::name() const
{
    return d ? d->name : QString();
}

/*!
    \since 4.8

    Returns the capabilities of this connection as negotiated with the bus
    server or peer. If this QDBusConnection is not connected, this function
    returns no capabilities.
*/
QDBusConnection::ConnectionCapabilities QDBusConnection::connectionCapabilities() const
{
    return d ? d->connectionCapabilities() : ConnectionCapabilities();
}

/*!
    Attempts to register the \a serviceName on the D-Bus server and
    returns \c true if the registration succeeded. The registration will
    fail if the name is already registered by another application.

    \sa unregisterService(), QDBusConnectionInterface::registerService()
*/
bool QDBusConnection::registerService(const QString &serviceName)
{
    if (interface() && interface()->registerService(serviceName)) {
        if (d) d->registerService(serviceName);
        return true;
    }
    return false;
}

/*!
    Unregisters the service \a serviceName that was previously
    registered with registerService() and returns \c true if it
    succeeded.

    \sa registerService(), QDBusConnectionInterface::unregisterService()
*/
bool QDBusConnection::unregisterService(const QString &serviceName)
{
    if (interface()->unregisterService(serviceName)) {
        if (d) d->unregisterService(serviceName);
        return true;
    }
    return false;
}

/*!
    \fn QDBusConnection QDBusConnection::sessionBus()

    Returns a QDBusConnection object opened with the session bus. The object
    reference returned by this function is valid until the application terminates,
    at which point the connection will be closed and the object deleted.
*/
QDBusConnection QDBusConnection::sessionBus()
{
    if (_q_manager.isDestroyed())
        return QDBusConnection(nullptr);
    return QDBusConnection(_q_manager()->busConnection(SessionBus));
}

/*!
    \fn QDBusConnection QDBusConnection::systemBus()

    Returns a QDBusConnection object opened with the system bus. The object reference returned
    by this function is valid until the QCoreApplication's destructor is run, when the
    connection will be closed and the object, deleted.
*/
QDBusConnection QDBusConnection::systemBus()
{
    if (_q_manager.isDestroyed())
        return QDBusConnection(nullptr);
    return QDBusConnection(_q_manager()->busConnection(SystemBus));
}

/*!
  \internal
*/
void QDBusConnectionPrivate::createBusService()
{
    Q_ASSERT(mode == ClientMode);
    QDBusConnection connection(this);
    busService = new QDBusConnectionInterface(connection, this);
    ref.deref(); // busService has increased the refcounting to us
                 // avoid cyclic refcounting

    QObject::connect(this, &QDBusConnectionPrivate::callWithCallbackFailed,
                     busService, emit &QDBusConnectionInterface::callWithCallbackFailed,
                     Qt::QueuedConnection);
}

/*!
    \since 4.8
    Returns the local machine ID as known to the D-Bus system. Each
    node or host that runs D-Bus has a unique identifier that can be
    used to distinguish it from other hosts if they are sharing
    resources like the filesystem.

    Note that the local machine ID is not guaranteed to be persistent
    across boots of the system, so this identifier should not be
    stored in persistent storage (like the filesystem). It is
    guaranteed to remain constant only during the lifetime of this
    boot session.
*/
QByteArray QDBusConnection::localMachineId()
{
    char *dbus_machine_id = q_dbus_get_local_machine_id();
    QByteArray result = dbus_machine_id;
    q_dbus_free(dbus_machine_id);
    return result;
}

/*!
    \namespace QDBus
    \inmodule QtDBus

    \brief The QDBus namespace contains miscellaneous identifiers used
    throughout the Qt D-Bus module.
*/

/*!
    \enum QDBus::CallMode

    This enum describes the various ways of placing a function call. The valid modes are:

    \value NoBlock              Place the call but don't wait for the reply (the reply's contents
                                will be discarded).
    \value Block                Don't use an event loop to wait for a reply, but instead block on
                                network operations while waiting. This means the
                                user-interface may not be updated until the function returns.
    \value BlockWithGui         Use the Qt event loop to wait for a reply. This means that the
                                user-interface will stay responsive (processing input events),
                                but it also means other events may happen, like signal delivery
                                and other D-Bus method calls.
    \value AutoDetect           Automatically detect if the called function has a reply.

    When using BlockWithGui, applications must be prepared for reentrancy in any function.
*/

/*!
    \fn void QDBusConnection::swap(QDBusConnection &other)

    Swaps this QDBusConnection instance with \a other.
*/

QT_END_NAMESPACE

#ifdef Q_OS_WIN
#  include <qt_windows.h>

QT_BEGIN_NAMESPACE
static void preventDllUnload()
{
    // Thread termination is really wacky on Windows. For some reason we don't
    // understand, exiting from the thread may try to unload the DLL. Since the
    // QDBusConnectionManager thread runs until the DLL is unloaded, we've got
    // a deadlock: the main thread is waiting for the manager thread to exit,
    // but the manager thread is attempting to acquire a lock to unload the DLL.
    //
    // We work around the issue by preventing the unload from happening in the
    // first place.
    //
    // For this trick, see
    // https://blogs.msdn.microsoft.com/oldnewthing/20131105-00/?p=2733

    static HMODULE self;
    GetModuleHandleEx(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                      GET_MODULE_HANDLE_EX_FLAG_PIN,
                      reinterpret_cast<const wchar_t *>(&self), // any address in this DLL
                      &self);
}
QT_END_NAMESPACE
#endif

#endif // QT_NO_DBUS
