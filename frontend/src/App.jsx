import React from 'react';
import UserForm from './components/UserForm';
import UserList from './components/UserList';

export default function App() {
  return (
    <div style={{ padding: '2rem' }}>
      <h1>User Management</h1>
      <UserForm />
      <hr />
      <UserList />
    </div>
  );
}

