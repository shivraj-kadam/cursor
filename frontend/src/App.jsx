import { useEffect, useState } from 'react'

const emptyForm = { name: '', email: '', course: '' }

export default function App() {
  const [students, setStudents] = useState([])
  const [form, setForm] = useState(emptyForm)
  const [editingId, setEditingId] = useState(null)
  const [status, setStatus] = useState('')

  const loadStudents = async () => {
    try {
      const res = await fetch('/api/students')
      if (!res.ok) throw new Error()
      setStudents(await res.json())
    } catch {
      setStatus('Backend/RDS is not reachable.')
    }
  }

  useEffect(() => { loadStudents() }, [])

  const submit = async (e) => {
    e.preventDefault()
    setStatus('')
    const url = editingId ? `/api/students/${editingId}` : '/api/students'
    const method = editingId ? 'PUT' : 'POST'
    try {
      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form)
      })
      if (!res.ok) throw new Error()
      setForm(emptyForm)
      setEditingId(null)
      setStatus(editingId ? 'Student updated.' : 'Student added.')
      loadStudents()
    } catch {
      setStatus('Unable to save student.')
    }
  }

  const remove = async (id) => {
    if (!confirm('Delete this student?')) return
    await fetch(`/api/students/${id}`, { method: 'DELETE' })
    loadStudents()
  }

  const edit = (student) => {
    setEditingId(student.id)
    setForm({ name: student.name, email: student.email, course: student.course })
  }

  return (
    <main className="container">
      <header>
        <p className="eyebrow">AWS 3-TIER DEMO</p>
        <h1>Student Management</h1>
        <p>React → Nginx → Frontend ALB → Frontend EC2 → Backend ALB → Spring Boot → Amazon RDS</p>
      </header>

      <section className="card">
        <h2>{editingId ? 'Edit student' : 'Add student'}</h2>
        <form onSubmit={submit}>
          <input required placeholder="Full name" value={form.name} onChange={e => setForm({...form, name:e.target.value})} />
          <input required type="email" placeholder="Email" value={form.email} onChange={e => setForm({...form, email:e.target.value})} />
          <input required placeholder="Course" value={form.course} onChange={e => setForm({...form, course:e.target.value})} />
          <button type="submit">{editingId ? 'Update' : 'Add'}</button>
          {editingId && <button type="button" className="secondary" onClick={() => {setEditingId(null);setForm(emptyForm)}}>Cancel</button>}
        </form>
        {status && <p className="status">{status}</p>}
      </section>

      <section className="card">
        <div className="section-title"><h2>Students</h2><button className="secondary" onClick={loadStudents}>Refresh</button></div>
        <div className="table-wrap">
          <table>
            <thead><tr><th>ID</th><th>Name</th><th>Email</th><th>Course</th><th>Actions</th></tr></thead>
            <tbody>
              {students.map(s => <tr key={s.id}>
                <td>{s.id}</td><td>{s.name}</td><td>{s.email}</td><td>{s.course}</td>
                <td><button onClick={() => edit(s)}>Edit</button> <button className="danger" onClick={() => remove(s.id)}>Delete</button></td>
              </tr>)}
            </tbody>
          </table>
          {!students.length && <p className="empty">No students yet.</p>}
        </div>
      </section>
    </main>
  )
}
