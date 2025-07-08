import React, { useEffect, useState } from 'react';
import axios from 'axios';

const API = '/api/users';

export default function UserList() {
  const [users, setUsers] = useState([]);

  const loadUsers = async () => {
    try {
      const res = await axios.get(API);
      setUsers(res.data);
    } catch (err) {
      console.error(err);
    }
  };

  const deleteUser = async email => {
    if (!window.confirm(`Delete user with email ${email}?`)) return;
    try {
      await axios.delete(`${API}/${email}`);
      loadUsers();
    } catch (err) {
      console.error(err);
      alert('Error deleting user');
    }
  };

  useEffect(() => {
    loadUsers();
  }, []);

  return (
    <div>
      <h2>Existing Users</h2>
      <ul>
        {users.map(user => (
          <li key={user.email}>
            {user.name} ({user.email}){' '}
            <button onClick={() => deleteUser(user.email)}>Delete</button>
          </li>
        ))}
      </ul>
    </div>
  );
}

