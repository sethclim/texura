// import { useState } from 'react'
import './App.css'

import {
  // useQuery,
  // useMutation,
  // useQueryClient,
  QueryClient,
  QueryClientProvider,
} from '@tanstack/react-query'

import { InferenceCard } from './InferenceCard'

const queryClient = new QueryClient()

function App() {
 

  return (
       <QueryClientProvider client={queryClient}>
        <h1>Texura</h1>
        <div className="card">
          <InferenceCard />
        </div>
      </QueryClientProvider>
  )
}

export default App
