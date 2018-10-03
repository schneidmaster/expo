import React from 'react';
import { Notifications } from 'expo';
import { StyleSheet, Text, View, Button } from 'react-native';

export default class UserNotificationsScreen extends React.Component {
  static navigationOptions = {
    title: 'Notifications',
  };

  state = {
    gotNotification: false,
    expoPushToken: null,
    actionId: null,
    userText: null,
  };

  async componentWillMount() {
    const action = {
      actionId: 'touch_action',
      buttonTitle: 'touch',
      isDestructive: true,
      isAuthenticationRequired: true,
    };

    const textAction = {
      actionId: 'add_action',
      buttonTitle: 'add',
      isDestructive: true,
      isAuthenticationRequired: false,
      textInput: {
        submitButtonTitle: 'button_name',
        placeholder: 'default text',
      },
    };

    await Notifications.setCategoryAsync('super-category', [action, textAction]);

    this._notificationListener = Notifications.addListener(e => {
      this.setState({ gotNotification: true, actionId: e.actionId, userText: e.userText });
      console.log('event received ', e.actionId);
    });
  }

  async componentDidMount() {
    this.setState({ expoPushToken: await Notifications.getExpoPushTokenAsync() });
  }

  componentWillUnmount() {
    this._notificationListener.remove();
    this._notificationListener = null;
  }

  _onButtonPress = () => {
    Notifications.presentLocalNotificationAsync({
      title: 'notification',
      body: 'notification-body',
      data: { scheduledAt: new Date().getTime() },
      categoryId: 'super-category',
    });
  };

  _schedule = () => {
    Notifications.scheduleLocalNotificationWithMatchAsync(
      {
        title: 'notification',
        body: 'notification-body',
        data: { scheduledAt: new Date().getTime() },
      },
      {
        hour: 15,
        minute: 4,
      }
    );
  };

  _waitTenSec = async () => {
    this.notificationID = await Notifications.scheduleLocalNotificationWithTimeIntervalAsync(
      {
        title: 'notification',
        body: 'notification-body',
        data: { scheduledAt: new Date().getTime() },
      },
      {
        'time-interval': 10,
      }
    );
  };

  _cancelWithId = () => {
    Notifications.cancelScheduledNotificationAsync(this.notificationID);
  };

  _cancelAll = () => {
    Notifications.cancelAllScheduledNotificationsAsync(this.notificationID);
  };

  render() {
    return (
      <View style={styles.container}>
        <Text>{this.state.gotNotification}</Text>
        <Text>notifications example</Text>
        <Button onPress={this._onButtonPress} title="trigger" />
        <Button onPress={this._schedule} title="schedule" />
        <Button onPress={this._waitTenSec} title="10 sec" />
        <Button onPress={this._cancelWithId} title="cancel" />
        <Button onPress={this._cancelAll} title="cancel all" />
        <Text> ExpoPushToken: {this.state.expoPushToken} </Text>
        <Text> categoryId: {this.state.categoryId} </Text>
        <Text> actionId: {this.state.actionId} </Text>
        <Text> userInput: {this.state.userText} </Text>
      </View>
    );
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    marginTop: 15,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
