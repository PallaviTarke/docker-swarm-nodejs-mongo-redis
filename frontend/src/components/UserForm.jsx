import React, { useState } from 'react';
import axios from 'axios';

const API = '/api/users';

export default function UserForm() {
  const [form, setForm] = useState({ name: '', email: '' });

  const handleChange = e => setForm({ ...form, [e.target.name]: e.target.value });

  const handleSubmit = async e => {
    e.preventDefault();
    try {
      await axios.post(API, form);
      alert('User added!');
      setForm({ name: '', email: '' });
    } catch (err) {
      console.error(err);
      alert('Failed to add user');
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <input name="name" placeholder="Name" value={form.name} onChange={handleChange} required />
      <input name="email" placeholder="Email" value={form.email} onChange={handleChange} required />
      <button type="submit">Add User</button>
    </form>
  );
}

